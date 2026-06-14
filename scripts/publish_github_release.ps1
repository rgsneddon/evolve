# Build (optional), deploy GitHub Pages, and publish a GitHub Release with platform binaries.
param(
    [string]$Version = '1.0.0',
    [string]$RepoName = 'evolve',
    [string]$DeployDir = '',
    [string]$ReleaseNotes = '',
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [switch]$SkipPages,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"

$tag = if ($Version -match '^v') { $Version } else { "v$Version" }
$owner = 'rgsneddon'
$remote = "https://github.com/$owner/$RepoName.git"

if (-not $DeployDir) {
    $DeployDir = Join-Path (Split-Path $Root -Parent) "${RepoName}_deploy"
}

Set-Location $Root

if (-not $SkipBuild) {
    if ($SkipTests) {
        & "$PSScriptRoot\build_all.ps1" -SkipTests
    } else {
        & "$PSScriptRoot\build_all.ps1"
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

try {
    & "$PSScriptRoot\deploy_web_github.ps1" -RepoName $RepoName
} catch {
    Write-Error $_
    exit 1
}

$webDir = Join-Path $Root 'build\web'
$releaseDir = Join-Path $Root "build\release\$tag"
if (Test-Path $releaseDir) { Remove-Item $releaseDir -Recurse -Force }
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$winSrc = Join-Path $Root 'build\windows\x64\runner\Release'
$winZip = Join-Path $releaseDir "evolve-$tag-windows-x64.zip"
if (-not (Test-Path (Join-Path $winSrc 'evolve.exe'))) {
    throw "Missing Windows build: build\windows\x64\runner\Release\evolve.exe"
}
Compress-Archive -Path (Join-Path $winSrc '*') -DestinationPath $winZip -Force

$apkSrc = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'
$apkOut = Join-Path $releaseDir "evolve-$tag-android.apk"
if (Test-Path $apkSrc) {
    Copy-Item $apkSrc $apkOut -Force
} else {
    Write-Host 'Android APK not found; release will omit APK asset.' -ForegroundColor Yellow
}

$pagesZip = Join-Path $Root "build\$RepoName-github-pages.zip"
if (-not (Test-Path $pagesZip)) {
    throw "Missing Pages package: build\$RepoName-github-pages.zip"
}
Copy-Item $pagesZip (Join-Path $releaseDir "$RepoName-github-pages.zip") -Force

if (-not $SkipPages) {
    if (-not (Test-Path (Join-Path $DeployDir '.git'))) {
        Write-Host "Cloning $remote -> $DeployDir" -ForegroundColor Cyan
        git clone $remote $DeployDir
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    Set-Location $DeployDir
    if (-not (git config user.email)) {
        git config user.email "$owner@users.noreply.github.com"
        git config user.name $owner
    }
    git fetch origin
    git checkout main
    git pull --ff-only origin main
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Get-ChildItem -Force | Where-Object {
        $_.Name -notin '.git', '.gitignore', 'README.md'
    } | Remove-Item -Recurse -Force

    Copy-Item -Path (Join-Path $webDir '*') -Destination $DeployDir -Recurse -Force

    $readmeSrc = Join-Path $Root 'README.md'
    if (Test-Path $readmeSrc) {
        Copy-Item $readmeSrc (Join-Path $DeployDir 'README.md') -Force
    }

    git add -A
    $status = git status --porcelain
    if ($status) {
        git commit -m "Deploy web $tag"
        if ($LASTEXITCODE -ne 0) {
            throw 'Pages deploy commit failed (set git user.name and user.email).'
        }
        if ($DryRun) {
            Write-Host '[dry-run] Would push Pages deploy to origin main' -ForegroundColor Yellow
        } else {
            git push origin main
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            Write-Host "Pages deploy pushed: https://$owner.github.io/$RepoName/" -ForegroundColor Green
        }
    } else {
        Write-Host 'Pages content unchanged; skipping push.' -ForegroundColor Yellow
    }
}

Set-Location $Root

$cred = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
if (-not $cred) { throw 'GitHub credentials not found. Run: gh auth login' }
$token = ($cred | Select-String '^password=(.+)$').Matches.Groups[1].Value
if (-not $token) { throw 'Could not read GitHub token from git credential helper.' }
$env:GH_TOKEN = $token

$assets = @(
    (Join-Path $releaseDir "evolve-$tag-windows-x64.zip"),
    (Join-Path $releaseDir "$RepoName-github-pages.zip")
)
if (Test-Path $apkOut) { $assets += $apkOut }

$missing = $assets | Where-Object { -not (Test-Path $_) }
if ($missing) {
    throw "Missing release assets: $($missing -join ', ')"
}

$defaultNotes = @"
Evolve Chronoflux $tag

- Web (GitHub Pages): https://$owner.github.io/$RepoName/
- Windows: extract ``evolve-$tag-windows-x64.zip`` and run ``evolve.exe``
- Android: install ``evolve-$tag-android.apk`` (when included)
- Pages bundle: ``$RepoName-github-pages.zip`` for manual deploy
"@
$notes = if ($ReleaseNotes.Trim()) { $ReleaseNotes.Trim() } else { $defaultNotes }

Write-Host ''
Write-Host "Creating GitHub Release $tag on $owner/$RepoName" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host '[dry-run] Would create release with:' -ForegroundColor Yellow
    $assets | ForEach-Object { Write-Host "  $_" }
    exit 0
}

& gh release create $tag `
    --repo "$owner/$RepoName" `
    --title "Evolve Chronoflux $tag" `
    --notes $notes `
    @assets

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host "Release published: https://github.com/$owner/$RepoName/releases/tag/$tag" -ForegroundColor Green