# Malware / threat scan and integrity probes for release installer binaries.

function Resolve-ReleaseVersionDir {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$VersionDir = '',
        [string]$Version = ''
    )

    if ($VersionDir -and (Test-Path $VersionDir)) {
        return (Resolve-Path $VersionDir).Path
    }

    $downloadsRoot = Join-Path $Root 'build\downloads'
    if (-not (Test-Path $downloadsRoot)) {
        throw "Missing build\downloads under $Root"
    }

    if ($Version) {
        $candidate = Join-Path $downloadsRoot "v$Version"
        if (Test-Path $candidate) { return $candidate }
        throw "Missing version directory: $candidate"
    }

    $latest = Get-ChildItem $downloadsRoot -Directory -Filter 'v*' |
        Sort-Object { [version]($_.Name -replace '^v', '') } -Descending |
        Select-Object -First 1
    if (-not $latest) {
        throw "No build\downloads\v* directories under $Root"
    }
    return $latest.FullName
}

function Get-ReleaseBinaries {
    param([Parameter(Mandatory = $true)][string]$VersionDir)

    Get-ChildItem $VersionDir -File | Where-Object {
        $_.Extension -in '.exe', '.apk', '.msi', '.msix' -and
        $_.Name -notlike 'CHECKSUMS*'
    }
}

function Find-DefenderMpCmdRun {
    $candidates = @(
        "${env:ProgramFiles}\Windows Defender\MpCmdRun.exe",
        "${env:ProgramFiles(x86)}\Windows Defender\MpCmdRun.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Invoke-DefenderFileScan {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    $mp = Find-DefenderMpCmdRun
    if (-not $mp) {
        return [PSCustomObject]@{
            Available = $false
            Clean = $false
            ExitCode = -1
            Output = 'MpCmdRun.exe not found'
        }
    }

    $out = & $mp -Scan -ScanType 3 -File $FilePath 2>&1 | Out-String
    $code = $LASTEXITCODE
    return [PSCustomObject]@{
        Available = $true
        Clean = ($code -eq 0)
        ExitCode = $code
        Output = $out.Trim()
    }
}

function Get-ApkPackageName {
    param([Parameter(Mandatory = $true)][string]$ApkPath)

    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    $aapt = Get-ChildItem -Path (Join-Path $sdk 'build-tools') -Recurse -Filter 'aapt.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $aapt) { return $null }

    $line = & $aapt.FullName dump badging $ApkPath 2>$null |
        Where-Object { $_ -match "^package: name='([^']+)'" } |
        Select-Object -First 1
    if ($line -match "name='([^']+)'") {
        return $Matches[1]
    }
    return $null
}

function Test-ReleaseBinaryIntegrity {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$ExpectedApkPackage = ''
    )

    $name = [IO.Path]::GetFileName($FilePath)
    $ext = [IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    $errors = [System.Collections.Generic.List[string]]::new()

    if ($ext -eq '.apk') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($FilePath)
        try {
            $hasManifest = $zip.Entries | Where-Object { $_.FullName -eq 'AndroidManifest.xml' }
            if (-not $hasManifest) {
                $errors.Add("$name missing AndroidManifest.xml")
            }
            $header = New-Object byte[] 2
            $fs = [IO.File]::OpenRead($FilePath)
            try { [void]$fs.Read($header, 0, 2) } finally { $fs.Dispose() }
            if ([Text.Encoding]::ASCII.GetString($header) -ne 'PK') {
                $errors.Add("$name is not a valid ZIP/APK (PK header)")
            }
        } finally {
            $zip.Dispose()
        }
        if ($ExpectedApkPackage) {
            $pkg = Get-ApkPackageName -ApkPath $FilePath
            if (-not $pkg) {
                $errors.Add("$name package id could not be read (aapt missing or bad APK)")
            } elseif ($pkg -ne $ExpectedApkPackage) {
                $errors.Add("$name package id '$pkg' != expected '$ExpectedApkPackage'")
            }
        }
    } elseif ($ext -eq '.exe') {
        $bytes = [IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
            $errors.Add("$name is not a valid PE executable (MZ header)")
        }
    }

    return [PSCustomObject]@{
        Ok = ($errors.Count -eq 0)
        Errors = $errors
    }
}

function Invoke-ReleaseArtifactSecurityScan {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$VersionDir = '',
        [string]$Version = '',
        [string]$ExpectedApkPackage = '',
        [string]$LogPath = '',
        [switch]$SkipDefender
    )

    $dir = Resolve-ReleaseVersionDir -Root $Root -VersionDir $VersionDir -Version $Version
    $binaries = @(Get-ReleaseBinaries -VersionDir $dir)
    if ($binaries.Count -eq 0) {
        throw "No release binaries (.exe/.apk) in $dir"
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("=== Release artifact security scan $(Get-Date -Format o) ===")
    $lines.Add("root=$Root")
    $lines.Add("versionDir=$dir")
    $lines.Add("binaryCount=$($binaries.Count)")

    $threats = 0
    $defenderUsed = $false
    $defenderUnavailable = $false

    foreach ($bin in $binaries) {
        $lines.Add("")
        $lines.Add("--- $($bin.Name) ($([math]::Round($bin.Length / 1MB, 2)) MB) ---")

        $integrity = Test-ReleaseBinaryIntegrity -FilePath $bin.FullName -ExpectedApkPackage $ExpectedApkPackage
        if ($integrity.Ok) {
            $lines.Add("integrity: OK")
        } else {
            foreach ($err in $integrity.Errors) {
                $lines.Add("integrity: FAIL $err")
                $threats++
            }
        }

        if (-not $SkipDefender) {
            $scan = Invoke-DefenderFileScan -FilePath $bin.FullName
            if (-not $scan.Available) {
                $defenderUnavailable = $true
                $lines.Add("defender: UNAVAILABLE ($($scan.Output))")
            } else {
                $defenderUsed = $true
                if ($scan.Clean) {
                    $lines.Add("defender: CLEAN (exit $($scan.ExitCode))")
                } else {
                    $lines.Add("defender: THREAT DETECTED (exit $($scan.ExitCode))")
                    if ($scan.Output) { $lines.Add($scan.Output) }
                    $threats++
                }
            }
        }
    }

    if ($defenderUnavailable -and -not $defenderUsed) {
        $lines.Add("")
        $lines.Add("fallback: Defender CLI unavailable; integrity probes only (checksum/signing gates still required)")
    }

    $lines.Add("")
    $lines.Add("threatDetections=$threats")
    $lines.Add("result=$(if ($threats -eq 0) { 'PASS' } else { 'FAIL' })")

    $text = $lines -join [Environment]::NewLine
    if ($LogPath) {
        $parent = Split-Path $LogPath -Parent
        if ($parent -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -Path $LogPath -Value $text -Encoding utf8
    } else {
        Write-Host $text
    }

    if ($threats -gt 0) {
        throw "Release security scan failed: $threats threat(s) in $dir"
    }

    return [PSCustomObject]@{
        VersionDir = $dir
        BinaryCount = $binaries.Count
        ThreatDetections = $threats
        DefenderUsed = $defenderUsed
        DefenderUnavailable = $defenderUnavailable
        LogPath = $LogPath
    }
}