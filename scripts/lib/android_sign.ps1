# Android release APK signing configuration and signature verification.

function Import-AndroidKeyProperties {
    param([string]$Root)

    $path = Join-Path $Root 'android\key.properties'
    if (-not (Test-Path $path)) { return $null }

    $props = @{}
    Get-Content $path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) { return }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        $props[$key] = $val
    }
    return [PSCustomObject]$props
}

function Test-AndroidReleaseKeystoreConfigured {
    param([string]$Root)

    $props = Import-AndroidKeyProperties -Root $Root
    if (-not $props) { return $false }

    $required = @('storePassword', 'keyPassword', 'keyAlias', 'storeFile')
    foreach ($key in $required) {
        if (-not $props.$key) { return $false }
    }

    $storePath = $props.storeFile
    if (-not [IO.Path]::IsPathRooted($storePath)) {
        $androidDir = Join-Path $Root 'android'
        $candidate = Join-Path $androidDir $storePath
        if (Test-Path $candidate) {
            $storePath = $candidate
        } else {
            $storePath = Join-Path $Root $storePath
        }
    }
    return (Test-Path $storePath)
}

function Assert-AndroidReleaseSigningReady {
    param(
        [string]$Root,
        [switch]$AllowDebug
    )

    if ($AllowDebug) { return }

    if (-not (Test-AndroidReleaseKeystoreConfigured -Root $Root)) {
        throw @'
Android release keystore is not configured.

Copy android/key.properties.example to android/key.properties and set:
  storeFile, storePassword, keyPassword, keyAlias

Generate a keystore with:
  scripts\setup_android_signing.ps1

Release APKs must not ship with the debug keystore (Play Protect "scan app" friction).
'@
    }
}

function Find-ApkSigner {
    if ($env:APKSIGNER_PATH -and (Test-Path $env:APKSIGNER_PATH)) {
        return $env:APKSIGNER_PATH
    }

    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) {
        $env:ANDROID_SDK_ROOT
    } else {
        Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    }

    $tool = Get-ChildItem -Path (Join-Path $sdk 'build-tools') -Recurse -Filter 'apksigner.bat' -ErrorAction SilentlyContinue |
        Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
        Select-Object -First 1
    if ($tool) { return $tool.FullName }

    throw @'
apksigner not found. Install Android SDK build-tools or set APKSIGNER_PATH.
'@
}

function Test-ApkReleaseSignature {
    param(
        [Parameter(Mandatory = $true)][string]$ApkPath,
        [string]$ApkSigner = ''
    )

    if (-not (Test-Path $ApkPath)) {
        throw "APK not found: $ApkPath"
    }

    if (-not $ApkSigner) {
        $ApkSigner = Find-ApkSigner
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $ApkSigner verify --print-certs --verbose $ApkPath 2>&1 | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }

    $text = ($out -join [Environment]::NewLine)
    if ($exitCode -ne 0) {
        return [PSCustomObject]@{
            Valid   = $false
            Message = "apksigner verify failed (exit $exitCode): $text"
            Schemes = @()
            Signer  = ''
            IsDebug = $false
        }
    }

    $schemes = @()
    if ($text -match 'v1 scheme \(JAR signing\):\s*true') { $schemes += 'v1' }
    if ($text -match 'v2 scheme \(APK Signature Scheme v2\):\s*true') { $schemes += 'v2' }
    if ($text -match 'v3 scheme \(APK Signature Scheme v3\):\s*true') { $schemes += 'v3' }

    $signer = ''
    if ($text -match 'Signer #1 certificate DN:\s*(.+)') {
        $signer = $Matches[1].Trim()
    }

    $isDebug = $signer -match 'CN=Android Debug' -or $signer -match 'Android Debug'
    $hasReleaseScheme = ($schemes -contains 'v2') -or ($schemes -contains 'v3')

    if ($isDebug) {
        return [PSCustomObject]@{
            Valid   = $false
            Message = 'APK is signed with the Android debug keystore'
            Schemes = $schemes
            Signer  = $signer
            IsDebug = $true
        }
    }

    if (-not $hasReleaseScheme) {
        return [PSCustomObject]@{
            Valid   = $false
            Message = 'APK missing v2/v3 signature schemes'
            Schemes = $schemes
            Signer  = $signer
            IsDebug = $false
        }
    }

    return [PSCustomObject]@{
        Valid   = $true
        Message = "Release APK signature OK ($($schemes -join ', '))"
        Schemes = $schemes
        Signer  = $signer
        IsDebug = $false
    }
}

function Test-ApkReleaseSignatureBatch {
    param(
        [Parameter(Mandatory = $true)][string[]]$ApkPaths,
        [switch]$AllowUnsigned
    )

    $failed = @()
    foreach ($apk in $ApkPaths) {
        $result = Test-ApkReleaseSignature -ApkPath $apk
        if ($result.Valid) {
            Write-Host "OK  $apk" -ForegroundColor Green
            Write-Host "    $($result.Message)" -ForegroundColor DarkGray
            if ($result.Signer) { Write-Host "    $($result.Signer)" -ForegroundColor DarkGray }
        } else {
            Write-Host "FAIL $apk" -ForegroundColor Red
            Write-Host "    $($result.Message)" -ForegroundColor Red
            $failed += $result
        }
    }

    if ($failed.Count -eq 0) { return $true }
    if ($AllowUnsigned) { return $false }
    throw "$($failed.Count) APK(s) failed release signature verification."
}