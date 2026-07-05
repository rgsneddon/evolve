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
. "$PSScriptRoot\lib\github.ps1"
. "$PSScriptRoot\lib\ghpages_downloads.ps1"

$tag = if ($Version -match '^v') { $Version } else { "v$Version" }
$owner = Get-GitHubOwner -Root $Root
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
    $deployArgs = @{ RepoName = $RepoName }
    if ($SkipBuild) { $deployArgs.SkipBuild = $true }
    & "$PSScriptRoot\deploy_web_github.ps1" @deployArgs
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

$versionNoV = $tag -replace '^v', ''
$installerDir = Join-Path $Root "build\downloads\v$versionNoV"
if (Test-Path $installerDir) {
    & "$PSScriptRoot\sign_download_packages.ps1" -Version $versionNoV -SourceDir $installerDir
    Get-ChildItem $installerDir -File | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $releaseDir $_.Name) -Force
    }
}

. "$PSScriptRoot\lib\package_checksum.ps1"
Get-ChildItem $releaseDir -File | Where-Object {
    $_.Extension -notin '.sha256', '.sha512', '.json' -and $_.Name -notlike 'CHECKSUMS*'
} | ForEach-Object {
    Write-PackageChecksumSidecar -PackagePath $_.FullName -Version $versionNoV | Out-Null
}
Write-VersionChecksumManifest -VersionDir $releaseDir | Out-Null

if (-not $SkipPages) {
    if (-not (Test-Path (Join-Path $DeployDir '.git'))) {
        Write-Host "Cloning $remote -> $DeployDir" -ForegroundColor Cyan
        git clone $remote $DeployDir
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    Set-Location $DeployDir
    Ensure-GitIdentity -Root $DeployDir -Owner $owner
    $pagesBranch = 'gh-pages'
    git fetch origin
    if (git show-ref --verify --quiet "refs/remotes/origin/$pagesBranch") {
        git checkout -B $pagesBranch "origin/$pagesBranch"
    } elseif (git show-ref --verify --quiet "refs/heads/$pagesBranch") {
        git checkout $pagesBranch
    } else {
        git checkout --orphan $pagesBranch
        git rm -rf . 2>$null | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    # Keep download packages and static pages alongside the Flutter web bundle.
    $preserveNames = @(
        '.git', '.gitignore', 'README.md',
        'downloads', 'download.html', 'privacy_policy.txt',
        'fcg_white_paper.html', 'fcg_white_paper.txt', 'docs'
    )
    Get-ChildItem -Force | Where-Object {
        $_.Name -notin $preserveNames
    } | Remove-Item -Recurse -Force

    Copy-Item -Path (Join-Path $webDir '*') -Destination $DeployDir -Recurse -Force

    $readmeSrc = Join-Path $Root 'README.md'
    if (Test-Path $readmeSrc) {
        Copy-Item $readmeSrc (Join-Path $DeployDir 'README.md') -Force
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
    Sync-GhPagesDownloads -Root $Root -DeployDir $DeployDir -Version $versionNoV

    git add -A
    $status = git status --porcelain
    if ($status) {
        git commit -m "Deploy web $tag"
        if ($LASTEXITCODE -ne 0) {
            throw 'Pages deploy commit failed (set git user.name and user.email).'
        }
        if ($DryRun) {
            Write-Host "[dry-run] Would push Pages deploy to origin $pagesBranch" -ForegroundColor Yellow
        } else {
            git push -u origin $pagesBranch --no-verify
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            Write-Host "Pages deploy pushed: https://$owner.github.io/$RepoName/" -ForegroundColor Green
        }
    } else {
        Write-Host 'Pages content unchanged; skipping push.' -ForegroundColor Yellow
    }
}

Set-Location $Root

$env:GH_TOKEN = Get-GitHubToken

$assets = Get-ChildItem $releaseDir -File | Where-Object {
    $_.Extension -notin '.sha256', '.sha512', '.json' -and $_.Name -notlike 'CHECKSUMS*'
} | ForEach-Object { $_.FullName }

# Include checksum sidecars in the GitHub Release.
$assets += Get-ChildItem $releaseDir -File | Where-Object {
    $_.Extension -in '.sha256', '.sha512' -or $_.Name -like 'CHECKSUMS*'
} | ForEach-Object { $_.FullName }

$missing = $assets | Where-Object { -not (Test-Path $_) }
if ($missing) {
    throw "Missing release assets: $($missing -join ', ')"
}

$defaultNotes = @"
Evolve Chronoflux $tag

- Downloads (installer packages): https://$owner.github.io/$RepoName/downloads/
- Web (GitHub Pages): https://$owner.github.io/$RepoName/
- Windows: ``evolve-$tag-windows-x64-setup.exe`` (or zip fallback)
- Android: ``evolve-$tag-android-setup.apk`` (when included)
- Pages bundle: ``$RepoName-github-pages.zip`` for manual deploy
- Verify downloads with attached ``.sha256`` / ``.sha512`` checksum files (minimum SHA-256)
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