# Bump Evolve release version and sync versioned source files.
# Always advances from the highest version seen locally, on origin/main, in tags, and recent bump commits.
param(
    [switch]$PatchOnly,
    [switch]$BuildOnly,
    [switch]$EnsureConsecutive
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'version_utils.ps1')
Set-Location $Root

if ($PatchOnly -and $BuildOnly) {
    throw 'Use only one of -PatchOnly or -BuildOnly'
}

$pubspecPath = Join-Path $Root 'pubspec.yaml'
$pubspec = Get-Content $pubspecPath -Raw
$local = Parse-AppVersion $pubspec
if (-not $local) {
    throw 'Could not parse version from pubspec.yaml (expected x.y.z+build)'
}

$pinText = $env:EVOLVE_RELEASE_PINNED
$pinFile = Join-Path $Root '.evolve-release-pin'
if (-not $pinText -and (Test-Path $pinFile)) {
    $pinText = (Get-Content $pinFile -Raw).Trim()
}
if ($pinText) {
    $pinned = Parse-AppVersion $pinText
    if ($pinned -and (Compare-AppVersion $local $pinned) -eq 0) {
        Write-Host "Release pinned at $($local.Major).$($local.Minor).$($local.Patch)+$($local.Build); skipping bump" -ForegroundColor Yellow
        exit 0
    }
}

if ($EnsureConsecutive) {
    if (-not $BuildOnly -and -not $PatchOnly) {
        $BuildOnly = $true
    }
}

$publishedMax = Get-PublishedMaxAppVersion -Root $Root
$next = Get-NextAppVersion -Root $Root -PatchOnly:$PatchOnly -BuildOnly:$BuildOnly -FromPublishedMax:$EnsureConsecutive
$release = $next.Release
$full = $next.Full
$nextParsed = Parse-AppVersion $full

if ($EnsureConsecutive -and (Compare-AppVersion $local $nextParsed) -ge 0) {
    Write-Host "Version already consecutive at $($local.Major).$($local.Minor).$($local.Patch)+$($local.Build) (published max $($publishedMax.Major).$($publishedMax.Minor).$($publishedMax.Patch)+$($publishedMax.Build), next $full)" -ForegroundColor Yellow
    exit 0
}

$pubspec = $pubspec -replace 'version:\s*[0-9.]+\+\d+', "version: $full"
Set-Content -Path $pubspecPath -Value $pubspec -NoNewline

$appVersionPath = Join-Path $Root 'lib\perc\perc_app_version.dart'
$appVersion = Get-Content $appVersionPath -Raw
$appVersion = $appVersion -replace "static const String current = '[^']+';", "static const String current = '$full';"
Set-Content -Path $appVersionPath -Value $appVersion -NoNewline

$versionJsonPath = Join-Path $Root 'version.json'
@{
    app_name     = 'evolve'
    version      = $release
    build_number = "$($nextParsed.Build)"
    package_name = 'evolve'
} | ConvertTo-Json -Compress | Set-Content -Path $versionJsonPath -Encoding utf8 -NoNewline

$downloadsIndex = Join-Path $Root 'downloads\index.html'
if (Test-Path $downloadsIndex) {
    $html = Get-Content $downloadsIndex -Raw
    $html = $html -replace 'Latest release: <strong>v[0-9.]+</strong> \(build \d+\)',
        "Latest release: <strong>v$release</strong> (build $($nextParsed.Build))"
    Set-Content -Path $downloadsIndex -Value $html -NoNewline
}
Write-Host "Version bumped to $full" -ForegroundColor Green
Write-Host "  (published max: $($publishedMax.Major).$($publishedMax.Minor).$($publishedMax.Patch)+$($publishedMax.Build))"
Write-Host "  pubspec.yaml"
Write-Host "  lib/perc/perc_app_version.dart"
Write-Host "  version.json"
if (Test-Path $downloadsIndex) { Write-Host "  downloads/index.html (release label only)" }