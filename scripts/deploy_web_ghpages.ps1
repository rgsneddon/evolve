# Deploy Flutter web build to gh-pages via evolve_deploy clone.
param(
    [string]$Version = '',
    [string]$DeployDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\github.ps1"
. "$PSScriptRoot\lib\ghpages_downloads.ps1"

if (-not $Version) {
    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
        $Version = $Matches[1]
    } else {
        throw 'Could not read version from pubspec.yaml'
    }
}

if (-not $DeployDir) {
    $DeployDir = Join-Path (Split-Path $Root -Parent) 'evolve_deploy'
}

$webDir = Join-Path $Root 'build\web'
$tag = "v$Version"
$required = @('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'assets', 'canvaskit', 'icons')
foreach ($item in $required) {
    if (-not (Test-Path (Join-Path $webDir $item))) {
        throw "Missing build\web\$item - run build_all.ps1 or deploy_web_github.ps1 first."
    }
}

if (-not (Test-Path (Join-Path $DeployDir '.git'))) {
    $owner = Get-GitHubOwner -Root $Root
    $remote = "https://github.com/$owner/evolve.git"
    Write-Host "Cloning $remote -> $DeployDir" -ForegroundColor Cyan
    git clone $remote $DeployDir
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Set-Location $DeployDir
Ensure-GitIdentity -Root $DeployDir
git fetch origin
git checkout -B gh-pages origin/gh-pages
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$preserveNames = @(
    '.git', '.gitignore', 'README.md',
    'downloads', 'download.html', 'privacy_policy.txt',
    'fcg_white_paper.html', 'fcg_white_paper.txt', 'docs'
)
Get-ChildItem -Force | Where-Object { $_.Name -notin $preserveNames } | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $webDir '*') -Destination $DeployDir -Recurse -Force

$nojekyll = Join-Path $DeployDir '.nojekyll'
if (-not (Test-Path $nojekyll)) {
    New-Item -ItemType File -Path $nojekyll -Force | Out-Null
}

foreach ($extra in @('download.html', 'privacy_policy.txt', 'fcg_white_paper.html', 'fcg_white_paper.txt')) {
    $src = Join-Path $Root $extra
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $DeployDir $extra) -Force
    }
}
$fcgDocsSrc = Join-Path $Root 'docs\fcg'
if (Test-Path $fcgDocsSrc) {
    $fcgDocsDst = Join-Path $DeployDir 'docs\fcg'
    if (-not (Test-Path $fcgDocsDst)) {
        New-Item -ItemType Directory -Path $fcgDocsDst -Force | Out-Null
    }
    Copy-Item (Join-Path $fcgDocsSrc '*') $fcgDocsDst -Recurse -Force
}
$versionJsonSrc = Join-Path $Root 'version.json'
if (Test-Path $versionJsonSrc) {
    Copy-Item $versionJsonSrc (Join-Path $DeployDir 'version.json') -Force
}

Sync-GhPagesDownloads -Root $Root -DeployDir $DeployDir -Version $Version

git add -A
$status = git status --porcelain
if (-not $status) {
    Write-Host 'Web content unchanged on gh-pages.' -ForegroundColor Yellow
    exit 0
}

git commit -m "Deploy web $tag"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git push -u origin gh-pages --no-verify
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$owner = Get-GitHubOwner -Root $Root
Write-Host "Pages deploy pushed: https://$owner.github.io/evolve/" -ForegroundColor Green