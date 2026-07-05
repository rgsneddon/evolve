# Build and package Evolve web output for GitHub Pages.
param(
    [string]$RepoName = 'evolve',
    [string]$GitHubOwner = '',
    [string]$GrokProxyUrl = $env:GROK_PROXY_URL,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"
. "$PSScriptRoot\lib\github.ps1"

if (-not $GitHubOwner) {
    $GitHubOwner = Get-GitHubOwner -Root $Root
}

$flutter = (Set-BuildEnvironment).FlutterExe
$baseHref = "/$RepoName/"
$webDir = Join-Path $Root 'build\web'
$zipPath = Join-Path $Root "build\$RepoName-github-pages.zip"

Set-Location $Root

& "$PSScriptRoot\write_grok_proxy_config.ps1" -ProxyUrl $GrokProxyUrl

if (-not $SkipBuild) {
    Write-Host "Building web with --base-href $baseHref" -ForegroundColor Cyan
    $defineArgs = @()
    if ($GrokProxyUrl) {
        $trimmed = $GrokProxyUrl.Trim().TrimEnd('/')
        Write-Host "Live Grok proxy: $trimmed" -ForegroundColor Cyan
        $defineArgs += "--dart-define=GROK_PROXY_URL=$trimmed"
    } else {
        Write-Host 'No GROK_PROXY_URL — web will use in-browser heuristic unless assets/config/grok_proxy.json is set.' -ForegroundColor Yellow
    }
    & $flutter build web --release --base-href $baseHref @defineArgs
}

$required = @(
    'index.html',
    'main.dart.js',
    'flutter_bootstrap.js',
    'assets',
    'canvaskit',
    'icons'
)
foreach ($item in $required) {
    $path = Join-Path $webDir $item
    if (-not (Test-Path $path)) {
        throw "Missing required deploy artifact: build\web\$item"
    }
}

$indexHtml = Get-Content (Join-Path $webDir 'index.html') -Raw
if ($indexHtml -notmatch [regex]::Escape("<base href=`"$baseHref`">")) {
    throw "index.html base href is wrong. Expected <base href=`"$baseHref`">. Rebuild with --base-href $baseHref"
}

# Prevent GitHub Pages Jekyll from stripping Flutter asset paths.
$nojekyll = Join-Path $webDir '.nojekyll'
if (-not (Test-Path $nojekyll)) { New-Item -ItemType File -Path $nojekyll -Force | Out-Null }

$licenseSrc = Join-Path $Root 'LICENSE'
if (Test-Path $licenseSrc) {
    Copy-Item $licenseSrc (Join-Path $webDir 'LICENSE') -Force
}

$readmeSrc = Join-Path $Root 'README.md'
if (Test-Path $readmeSrc) {
    Copy-Item $readmeSrc (Join-Path $webDir 'README.md') -Force
}

$versionJsonSrc = Join-Path $Root 'version.json'
if (Test-Path $versionJsonSrc) {
    Copy-Item $versionJsonSrc (Join-Path $webDir 'version.json') -Force
}

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $webDir '*') -DestinationPath $zipPath -Force

Write-Host ''
Write-Host 'Deploy package ready:' -ForegroundColor Green
Write-Host "  $zipPath"
Write-Host ''
Write-Host 'Upload to GitHub (repo root must contain assets/, canvaskit/, icons/):' -ForegroundColor Yellow
Write-Host "  1. Open https://github.com/$GitHubOwner/$RepoName"
Write-Host '  2. Delete old web files at repo root (keep README.md if you want).'
Write-Host '  3. Upload EVERYTHING inside build\web\ (all 3 folders + all files).'
Write-Host "     Or extract $RepoName-github-pages.zip and upload those contents."
Write-Host '  4. Settings -> Pages -> Source: Deploy from branch main, folder / (root).'
Write-Host '     (If you see "There isn''t a GitHub Pages site here", Pages is not enabled yet.)'
Write-Host "  5. Wait 1-2 minutes, then open: https://$GitHubOwner.github.io/$RepoName/"
Write-Host ''
Write-Host 'Verify after deploy:' -ForegroundColor Yellow
Write-Host "  https://$GitHubOwner.github.io/$RepoName/canvaskit/canvaskit.js  (must be 200, not 404)"
Write-Host "  index.html must contain: <base href=`"$baseHref`">"

exit 0