# Sign all downloadable packages in a version folder with SHA-256 and SHA-512 checksums.
param(
    [string]$Version = '',
    [string]$SourceDir = '',
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\package_checksum.ps1"
. "$PSScriptRoot\lib\release_signing_status.ps1"
. "$PSScriptRoot\lib\security_scan.ps1"
. "$PSScriptRoot\lib\dependency_audit.ps1"
Set-Location $Root

if (-not $Version) {
    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
        $Version = $Matches[1]
    } else {
        throw 'Could not read version from pubspec.yaml'
    }
}

if (-not $SourceDir) {
    $SourceDir = Join-Path $Root "build\downloads\v$Version"
}

if (-not (Test-Path $SourceDir)) {
    throw "Missing download packages: $SourceDir"
}

# Binaries ship on GitHub Releases; gh-pages only hosts checksum sidecars/index.
$baseUrl = "https://github.com/rgsneddon/evolve/releases/download/v$Version"

if ($VerifyOnly) {
    Invoke-ReleaseArtifactSecurityScan `
        -Root $Root `
        -VersionDir $SourceDir `
        -ExpectedApkPackage 'com.evolve.chronoflux' | Out-Null
    Test-VersionPackageChecksums -VersionDir $SourceDir -RequireSidecars
    Write-Host "Checksum verification passed for v$Version" -ForegroundColor Green
    exit 0
}

Invoke-DependencyAudit -Root $Root | Out-Null
Invoke-ReleaseArtifactSecurityScan `
    -Root $Root `
    -VersionDir $SourceDir `
    -ExpectedApkPackage 'com.evolve.chronoflux' | Out-Null

$packages = Get-ChildItem $SourceDir -File | Where-Object {
    $_.Extension -notin '.sha256', '.sha512', '.json' -and
    $_.Name -notlike 'CHECKSUMS*'
}

foreach ($pkg in $packages) {
    $platform = if ($pkg.Name -match 'windows') { 'windows' } elseif ($pkg.Name -match 'android|apk') { 'android' } elseif ($pkg.Name -match 'ios|\.ipa$') { 'ios' } else { 'package' }
    Write-PackageChecksumSidecar `
        -PackagePath $pkg.FullName `
        -Version $Version `
        -Platform $platform `
        -Url "$baseUrl/$($pkg.Name)"
    Write-Host "Signed: $($pkg.Name) (SHA-256 + SHA-512)" -ForegroundColor Cyan
}

$entries = Write-VersionChecksumManifest -VersionDir $SourceDir -BaseUrl $baseUrl
Test-VersionPackageChecksums -VersionDir $SourceDir -RequireSidecars | Out-Null

$signingStatus = Write-ReleaseSigningStatusManifest -Root $Root -VersionDir $SourceDir
if (-not $signingStatus.WindowsAuthenticodeSigned) {
    Write-Host "Windows setup is NOT Authenticode-signed: $($signingStatus.WindowsMessage)" -ForegroundColor Yellow
}
if (-not $signingStatus.AndroidReleaseSigned) {
    Write-Host "Android APK is NOT release-signed: $($signingStatus.AndroidMessage)" -ForegroundColor Yellow
}

$indexInfo = Update-DownloadsIndexPage -VersionDir $SourceDir -Version $Version
$perccentInfo = Update-PerccentDownloadsIndexSection

Write-Host ''
Write-Host "Signed $($entries.Count) package(s) in $SourceDir" -ForegroundColor Green
$iosLabel = if ($indexInfo.iOS) { ", $($indexInfo.iOS)" } else { '' }
Write-Host "  downloads/index.html -> v$($indexInfo.Version) ($($indexInfo.Windows), $($indexInfo.Android)$iosLabel)" -ForegroundColor Cyan
if ($perccentInfo) {
    $perccentIos = if ($perccentInfo.iOS) { ", $($perccentInfo.iOS)" } else { '' }
    Write-Host "  downloads/index.html perccent-wallet -> v$($perccentInfo.Version) ($($perccentInfo.Windows), $($perccentInfo.Android)$perccentIos)" -ForegroundColor Cyan
    Write-Host "    SHA-256: $($perccentInfo.Sha256)" -ForegroundColor Cyan
}
Write-Host "  CHECKSUMS.sha256"
Write-Host "  CHECKSUMS.sha512"
Write-Host "  checksums.json"