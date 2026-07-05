# Bump Evolve release version (+1 patch, +1 build) and sync versioned source files.
param(
    [switch]$PatchOnly,
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$pubspecPath = Join-Path $Root 'pubspec.yaml'
$pubspec = Get-Content $pubspecPath -Raw
if ($pubspec -notmatch 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    throw 'Could not parse version from pubspec.yaml (expected x.y.z+build)'
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4]

if ($BuildOnly) {
    $build += 1
} elseif ($PatchOnly) {
    $patch += 1
    $build += 1
} else {
    $patch += 1
    $build += 1
}

$release = "$major.$minor.$patch"
$full = "$release+$build"

$pubspec = $pubspec -replace 'version:\s*[0-9.]+\+\d+', "version: $full"
Set-Content -Path $pubspecPath -Value $pubspec -NoNewline

$appVersionPath = Join-Path $Root 'lib\perc\perc_app_version.dart'
$appVersion = Get-Content $appVersionPath -Raw
$appVersion = $appVersion -replace "static const String current = '[^']+';", "static const String current = '$full';"
Set-Content -Path $appVersionPath -Value $appVersion -NoNewline

$versionJsonPath = Join-Path $Root 'version.json'
@{
    app_name = 'evolve'
    version = $release
    build_number = "$build"
    package_name = 'evolve'
} | ConvertTo-Json -Compress | Set-Content -Path $versionJsonPath -Encoding utf8 -NoNewline

$downloadsIndex = Join-Path $Root 'downloads\index.html'
if (Test-Path $downloadsIndex) {
    $html = Get-Content $downloadsIndex -Raw
    $html = $html -replace 'Latest release: <strong>v[0-9.]+</strong> \(build \d+\)',
        "Latest release: <strong>v$release</strong> (build $build)"
    Set-Content -Path $downloadsIndex -Value $html -NoNewline
}

Write-Host "Version bumped to $full" -ForegroundColor Green
Write-Host "  pubspec.yaml"
Write-Host "  lib/perc/perc_app_version.dart"
Write-Host "  version.json"
if (Test-Path $downloadsIndex) { Write-Host "  downloads/index.html (release label only)" }