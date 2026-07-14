# Probe published installer artifacts for Authenticode / release APK signing status.

function Get-ReleaseVersionDir {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$Version = ''
    )

    if (-not $Version) {
        $pubspec = Join-Path $Root 'pubspec.yaml'
        if (Test-Path $pubspec) {
            $pub = Get-Content $pubspec -Raw
            if ($pub -match 'version:\s*([0-9.]+)\+') {
                $Version = $Matches[1]
            }
        }
    }
    if (-not $Version) {
        throw 'Could not infer release version'
    }

    $dir = Join-Path $Root "build\downloads\v$Version"
    if (-not (Test-Path $dir)) {
        throw "Missing release directory: $dir"
    }
    return $dir
}

function Get-ReleaseSigningStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$VersionDir = '',
        [string]$Version = ''
    )

    . (Join-Path $PSScriptRoot 'code_sign.ps1')
    . (Join-Path $PSScriptRoot 'android_sign.ps1')

    if (-not $VersionDir) {
        $VersionDir = Get-ReleaseVersionDir -Root $Root -Version $Version
    }

    $win = Get-ChildItem $VersionDir -File -Filter 'evolve-v*-windows-x64-setup.exe' | Select-Object -First 1
    $apk = Get-ChildItem $VersionDir -File -Filter 'evolve-v*-android-setup.apk' | Select-Object -First 1

    $windowsSigned = $false
    $windowsMessage = 'Windows setup not found'
    if ($win) {
        try {
            $signTool = Find-SignTool
            $verify = Test-AuthenticodeTrustedSignature -FilePath $win.FullName -SignTool $signTool
            $windowsSigned = $verify.Valid
            $windowsMessage = $verify.Message
        } catch {
            $windowsMessage = $_.Exception.Message
        }
    }

    $androidReleaseSigned = $false
    $androidMessage = 'Android APK not found'
    $androidDebug = $false
    if ($apk) {
        try {
            $apkVerify = Test-ApkReleaseSignature -ApkPath $apk.FullName
            $androidReleaseSigned = $apkVerify.Valid
            $androidMessage = $apkVerify.Message
            $androidDebug = $apkVerify.IsDebug
        } catch {
            $androidMessage = $_.Exception.Message
        }
    }

    return [PSCustomObject]@{
        VersionDir              = $VersionDir
        WindowsSetup            = if ($win) { $win.Name } else { '' }
        WindowsAuthenticodeSigned = $windowsSigned
        WindowsMessage          = $windowsMessage
        AndroidApk              = if ($apk) { $apk.Name } else { '' }
        AndroidReleaseSigned    = $androidReleaseSigned
        AndroidDebugSigned      = $androidDebug
        AndroidMessage          = $androidMessage
        ProbedUtc               = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Write-ReleaseSigningStatusManifest {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$VersionDir = '',
        [string]$Version = ''
    )

    $status = Get-ReleaseSigningStatus -Root $Root -VersionDir $VersionDir -Version $Version
    $manifestPath = Join-Path $status.VersionDir 'signing-status.json'
    @{
        probedUtc = $status.ProbedUtc
        windows = @{
            file = $status.WindowsSetup
            authenticodeSigned = $status.WindowsAuthenticodeSigned
            message = $status.WindowsMessage
        }
        android = @{
            file = $status.AndroidApk
            releaseSigned = $status.AndroidReleaseSigned
            debugSigned = $status.AndroidDebugSigned
            message = $status.AndroidMessage
        }
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding utf8

    return $status
}

function Get-InstallNotesSigningCopy {
    param([Parameter(Mandatory = $true)]$Status)

    $winNote = if ($Status.WindowsAuthenticodeSigned) {
        'Windows packages are Authenticode-signed for a trusted install path.'
    } else {
        'Windows SmartScreen may ask you to confirm until Authenticode-signed releases ship.'
    }

    $androidNote = if ($Status.AndroidReleaseSigned) {
        'APK is signed with the Evolve release key (not debug).'
    } elseif ($Status.AndroidDebugSigned) {
        'APK uses debug signing; Play Protect may prompt to scan the app.'
    } else {
        'Verify SHA-256 before installing.'
    }

    $integrity = if ($Status.WindowsAuthenticodeSigned -and $Status.AndroidReleaseSigned) {
        'Evolve packages are <strong>Authenticode-signed (Windows)</strong> and <strong>release-key signed (Android)</strong>, with SHA-256 / SHA-512 sidecars on <a href="https://github.com/rgsneddon/evolve/releases">Evolve Releases</a>.'
    } elseif ($Status.WindowsAuthenticodeSigned) {
        'Evolve Windows packages are <strong>Authenticode-signed</strong>; Android uses release-key signing when the release keystore is configured. SHA-256 / SHA-512 sidecars on <a href="https://github.com/rgsneddon/evolve/releases">Evolve Releases</a>.'
    } elseif ($Status.AndroidReleaseSigned) {
        'Evolve Android APK is <strong>release-key signed</strong>. Windows installers are checksum-verified (not yet Authenticode-signed). SHA-256 / SHA-512 sidecars on <a href="https://github.com/rgsneddon/evolve/releases">Evolve Releases</a>.'
    } else {
        'Evolve packages ship with <strong>SHA-256</strong> / <strong>SHA-512</strong> sidecars (not Authenticode-signed on Windows). Verify on <a href="https://github.com/rgsneddon/evolve/releases">Evolve Releases</a>.'
    }

    return [PSCustomObject]@{
        WindowsNote = $winNote
        AndroidNote = $androidNote
        IntegrityLine = $integrity
    }
}

function Update-DownloadsInstallNotesForSigning {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$DownloadsIndex = '',
        [string]$DownloadHtml = '',
        [string]$VersionDir = '',
        [string]$Version = ''
    )

    if (-not $DownloadsIndex) {
        $DownloadsIndex = Join-Path $Root 'downloads\index.html'
    }
    if (-not $DownloadHtml) {
        $DownloadHtml = Join-Path $Root 'download.html'
    }

    $status = Get-ReleaseSigningStatus -Root $Root -VersionDir $VersionDir -Version $Version
    $copy = Get-InstallNotesSigningCopy -Status $status
    Write-ReleaseSigningStatusManifest -Root $Root -VersionDir $status.VersionDir | Out-Null

    foreach ($path in @($DownloadsIndex, $DownloadHtml)) {
        if (-not (Test-Path $path)) { continue }
        $html = Get-Content $path -Raw

        foreach ($pattern in @(
            'Windows SmartScreen may ask you to confirm until Authenticode-signed releases ship\.',
            'Windows packages are Authenticode-signed for a trusted install path\.',
            'Windows SmartScreen may ask you to confirm\.'
        )) {
            if ($html -match $pattern) {
                $html = $html -replace $pattern, $copy.WindowsNote
                break
            }
        }

        foreach ($pattern in @(
            'APK is signed with the Evolve release key \(not debug\)\.',
            'APK uses debug signing; Play Protect may prompt to scan the app\.',
            'Verify SHA-256 before installing\. Camera permission'
        )) {
            if ($html -match $pattern) {
                if ($pattern -eq 'Verify SHA-256 before installing\. Camera permission') {
                    $html = $html -replace 'Verify SHA-256 before installing\. Camera',
                        "$($copy.AndroidNote) Camera"
                } else {
                    $html = $html -replace $pattern, $copy.AndroidNote
                }
                break
            }
        }

        if ($path -like '*index.html') {
            $integrityPatterns = @(
                'Evolve packages are <strong>Authenticode-signed \(Windows\)</strong> and <strong>release-key signed \(Android\)</strong>, with SHA-256 / SHA-512 sidecars on <a href="https://github.com/rgsneddon/evolve/releases">Evolve Releases</a>\. MY PERC: <a href="https://github.com/rgsneddon/perccent-wallet/releases/tag/v1\.1\.6">perccent-wallet v1\.1\.6</a>\.',
                'Evolve Android APK is <strong>release-key signed</strong>\. Windows installers are checksum-verified \(not yet Authenticode-signed\)\. SHA-256 / SHA-512 sidecars on <a href="https://github.com/rgsneddon/evolve/releases">Evolve Releases</a>\. MY PERC: <a href="https://github.com/rgsneddon/perccent-wallet/releases/tag/v1\.1\.6">perccent-wallet v1\.1\.6</a>\.',
                'Evolve packages ship with <strong>SHA-256</strong> / <strong>SHA-512</strong> sidecars \(not Authenticode-signed on Windows\)\. Verify on <a href="https://github.com/rgsneddon/evolve/releases">Evolve Releases</a>\. MY PERC: <a href="https://github.com/rgsneddon/perccent-wallet/releases/tag/v1\.1\.6">perccent-wallet v1\.1\.6</a>\.'
            )
            $replacement = if ($copy.IntegrityLine -match 'MY PERC') {
                $copy.IntegrityLine
            } else {
                "$($copy.IntegrityLine) MY PERC: <a href=`"https://github.com/rgsneddon/perccent-wallet/releases/tag/v1.1.6`">perccent-wallet v1.1.6</a>."
            }
            foreach ($pattern in $integrityPatterns) {
                if ($html -match $pattern) {
                    $html = $html -replace $pattern, $replacement
                    break
                }
            }
        } else {
            $integrityPatterns = @(
                'Packages are <strong>Authenticode-signed \(Windows\)</strong> and <strong>release-key signed \(Android\)</strong>, with SHA-256 and SHA-512 checksum sidecars\.',
                'Every package ships with <strong>SHA-256</strong> and <strong>SHA-512</strong> checksum sidecars \(not Authenticode-signed\)\.'
            )
            foreach ($pattern in $integrityPatterns) {
                if ($html -match $pattern) {
                    $html = $html -replace $pattern, $copy.IntegrityLine
                    break
                }
            }
        }

        Set-Content -Path $path -Value $html -NoNewline
    }

    return [PSCustomObject]@{
        Status = $status
        Copy = $copy
    }
}

function Assert-PublishReleaseSigningGate {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$Version = '',
        [switch]$AllowUnsigned
    )

    if ($AllowUnsigned) { return $null }

    $status = Get-ReleaseSigningStatus -Root $Root -Version $Version
    $blockers = [System.Collections.Generic.List[string]]::new()

    if (-not $status.WindowsAuthenticodeSigned) {
        $blockers.Add("Windows setup is not Authenticode-signed: $($status.WindowsMessage)")
    }
    if (-not $status.AndroidReleaseSigned) {
        $blockers.Add("Android APK is not release-signed: $($status.AndroidMessage)")
    }

    if ($blockers.Count -eq 0) {
        Write-ReleaseSigningStatusManifest -Root $Root -VersionDir $status.VersionDir | Out-Null
        Write-Host 'Release signing verification passed (Windows Authenticode + Android release key).' -ForegroundColor Green
        return $status
    }

    throw @"
Release publish blocked: installer signing verification failed.
$($blockers -join [Environment]::NewLine)

Fix Azure Trusted Signing (metadata.json profile + AADSTS530035) or use PFX mode,
then rebuild with scripts\build_installers.ps1. Use -SkipCodeSign only for dev builds.
"@
}