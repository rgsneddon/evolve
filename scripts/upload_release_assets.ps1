# Attach this machine's staged installers to the single GitHub Release for $Version.
# Windows: Windows / Linux / Arch. Mac: Android / macOS / iOS.
# Never creates a platform-suffix tag. See docs/GITHUB_RELEASES.md.
param(
    [string]$Version = '',
    [string]$RepoName = 'evolve',
    [switch]$Draft,
    [switch]$PublishNow
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\github.ps1"
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

$tag = Get-EvolveCanonicalReleaseTag -Version $Version
$versionNoV = $tag -replace '^v', ''
$owner = Get-GitHubOwner -Root $Root
$srcDir = Join-Path $Root "build\downloads\v$versionNoV"
if (-not (Test-Path $srcDir)) {
    throw "Missing staged packages: $srcDir"
}

$assets = Get-ChildItem $srcDir -File | ForEach-Object { $_.FullName }
if (-not $assets) {
    throw "No files to upload in $srcDir"
}

$env:GH_TOKEN = Get-GitHubToken

$exists = $false
$prev = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
gh release view $tag --repo "$owner/$RepoName" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $exists = $true }
$ErrorActionPreference = $prev

Write-Host "Uploading $($assets.Count) asset(s) to $owner/$RepoName $tag" -ForegroundColor Cyan
if ($exists) {
    & gh release upload $tag --repo "$owner/$RepoName" --clobber @assets
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($PublishNow) {
        & gh release edit $tag --repo "$owner/$RepoName" --draft=false --latest
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} else {
    $createArgs = @(
        $tag,
        '--repo', "$owner/$RepoName",
        '--title', "Evolve Chronoflux $tag",
        '--notes', "Evolve $tag — attach remaining platform packages to this same tag."
    )
    if (-not $PublishNow) { $createArgs += '--draft' }
    else { $createArgs += '--latest' }
    & gh release create @createArgs @assets
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Assets on https://github.com/$owner/$RepoName/releases/tag/$tag" -ForegroundColor Green
