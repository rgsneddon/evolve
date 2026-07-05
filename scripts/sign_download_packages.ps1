# Sign all downloadable packages in a version folder with SHA-256 and SHA-512 checksums.
param(
    [string]$Version = '',
    [string]$SourceDir = '',
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\package_checksum.ps1"
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

$baseUrl = "https://rgsneddon.github.io/evolve/downloads/v$Version"

if ($VerifyOnly) {
    Test-VersionPackageChecksums -VersionDir $SourceDir -RequireSidecars
    Write-Host "Checksum verification passed for v$Version" -ForegroundColor Green
    exit 0
}

$packages = Get-ChildItem $SourceDir -File | Where-Object {
    $_.Extension -notin '.sha256', '.sha512', '.json' -and
    $_.Name -notlike 'CHECKSUMS*'
}

foreach ($pkg in $packages) {
    $platform = if ($pkg.Name -match 'windows') { 'windows' } elseif ($pkg.Name -match 'android|apk') { 'android' } else { 'package' }
    Write-PackageChecksumSidecar `
        -PackagePath $pkg.FullName `
        -Version $Version `
        -Platform $platform `
        -Url "$baseUrl/$($pkg.Name)"
    Write-Host "Signed: $($pkg.Name) (SHA-256 + SHA-512)" -ForegroundColor Cyan
}

$entries = Write-VersionChecksumManifest -VersionDir $SourceDir -BaseUrl $baseUrl
Test-VersionPackageChecksums -VersionDir $SourceDir -RequireSidecars | Out-Null

$indexInfo = Update-DownloadsIndexPage -VersionDir $SourceDir -Version $Version

Write-Host ''
Write-Host "Signed $($entries.Count) package(s) in $SourceDir" -ForegroundColor Green
Write-Host "  downloads/index.html -> v$($indexInfo.Version) ($($indexInfo.Windows), $($indexInfo.Android))" -ForegroundColor Cyan
Write-Host "  CHECKSUMS.sha256"
Write-Host "  CHECKSUMS.sha512"
Write-Host "  checksums.json"