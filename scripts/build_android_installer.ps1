# Build a versioned Android APK package with SHA-256 checksum (mirrors Windows installer flow).
param(
    [string]$Version = '',
    [string]$Build = '',
    [switch]$SkipApkBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"

Set-Location $Root

if (-not $Version -or -not $Build) {
    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
        if (-not $Version) { $Version = $Matches[1] }
        if (-not $Build) { $Build = $Matches[2] }
    } else {
        throw 'Could not read version from pubspec.yaml'
    }
}

$apkSrc = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'

if (-not $SkipApkBuild) {
    & "$PSScriptRoot\build.ps1" -Platform apk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Test-Path $apkSrc)) {
    throw "Missing Android release APK: $apkSrc"
}

function Get-ApkAbis([string]$ApkPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
    try {
        $abis = $zip.Entries |
            Where-Object { $_.FullName -match '^lib/([^/]+)/libapp\.so$' } |
            ForEach-Object { $Matches[1] } |
            Sort-Object -Unique
        return ($abis -join ', ')
    } finally {
        $zip.Dispose()
    }
}

$publishedName = "evolve-v$Version-android-setup.apk"
$stagingDir = Join-Path $Root "build\installer\android"
$versionedDir = Join-Path $Root "build\downloads\v$Version"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $versionedDir -Force | Out-Null

$stagingPath = Join-Path $stagingDir $publishedName
$publishedPath = Join-Path $versionedDir $publishedName
Copy-Item $apkSrc $stagingPath -Force
Copy-Item $stagingPath $publishedPath -Force

$abis = Get-ApkAbis $publishedPath
$sizeMb = [math]::Round((Get-Item $publishedPath).Length / 1MB, 1)
$hash = (Get-FileHash $publishedPath -Algorithm SHA256).Hash.ToLowerInvariant()
$shaPath = "$publishedPath.sha256"
$secureUrl = "https://rgsneddon.github.io/evolve/downloads/v$Version/$publishedName"

@(
    "$hash  $publishedName",
    "version=$Version",
    "build=$Build",
    "platform=android",
    "abis=$abis",
    "minSdk=23",
    "url=$secureUrl"
) | Set-Content -Path $shaPath -Encoding utf8

$manifestPath = Join-Path $Root "installer\android\evolve-v$Version-android.json"
@{
    name = $publishedName
    version = $Version
    build = $Build
    platform = 'android'
    abis = ($abis -split ', ')
    minSdk = 23
    sizeBytes = (Get-Item $publishedPath).Length
    sizeMb = $sizeMb
    sha256 = $hash
    url = $secureUrl
} | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding utf8

Write-Host ''
Write-Host "Android installer v$Version (build $Build) ready:" -ForegroundColor Green
Write-Host "  $publishedPath"
Write-Host "  $shaPath"
Write-Host "  ABIs: $abis"
Write-Host "  Size: $sizeMb MB"
Write-Host ''
Write-Host 'Secure versioned URL (after gh-pages deploy):' -ForegroundColor Cyan
Write-Host "  $secureUrl"
Write-Host ''
Write-Host "SHA-256: $hash" -ForegroundColor Cyan