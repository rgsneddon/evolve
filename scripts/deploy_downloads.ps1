# Deploy versioned download checksum manifests to GitHub Pages (gh-pages branch).
param(
    [string]$Version = '',
    [string]$GhPagesWorktree = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\package_checksum.ps1"
. "$PSScriptRoot\lib\github.ps1"
. "$PSScriptRoot\lib\ghpages_downloads.ps1"
Set-Location $Root

if (-not $Version) {
    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
        $Version = $Matches[1]
    } else {
        throw 'Could not read version from pubspec.yaml'
    }
}

if (-not $GhPagesWorktree) {
    $GhPagesWorktree = Join-Path (Split-Path $Root -Parent) 'evolve_ghpages'
}

$srcDir = Join-Path $Root "build\downloads\v$Version"
if (-not (Test-Path $srcDir)) {
    throw "Missing staged downloads: $srcDir. Run build_windows_installer.ps1 and build_android_installer.ps1 first."
}

& "$PSScriptRoot\sign_download_packages.ps1" -Version $Version -SourceDir $srcDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Test-VersionPackageChecksums -VersionDir $srcDir -RequireSidecars | Out-Null

if (-not (Test-Path (Join-Path $GhPagesWorktree '.git'))) {
    Write-Host "Creating gh-pages worktree at $GhPagesWorktree" -ForegroundColor Cyan
    git fetch origin gh-pages
    git worktree add $GhPagesWorktree origin/gh-pages
}

Set-Location $GhPagesWorktree
Ensure-GitIdentity -Root $GhPagesWorktree
Sync-GhPagesBranch -Branch 'gh-pages' -Remote 'origin'

$dstDir = Join-Path $GhPagesWorktree "downloads\v$Version"
New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
foreach ($bin in @('*-android-setup.apk', '*-windows-x64-setup.exe', '*-ios-setup.ipa')) {
    Get-ChildItem $dstDir -Filter $bin -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force
        git rm -f --ignore-unmatch "downloads/v$Version/$($_.Name)" 2>$null | Out-Null
    }
}

Get-GhPagesChecksumArtifacts -StagedDir $srcDir | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dstDir $_.Name) -Force
}

foreach ($page in @('downloads\index.html', 'download.html')) {
    $srcPage = Join-Path $Root $page
    $dstPage = Join-Path $GhPagesWorktree $page
    if (Test-Path $srcPage) {
        Copy-Item $srcPage $dstPage -Force
    }
}

$versionJsonSrc = Join-Path $Root 'version.json'
if (Test-Path $versionJsonSrc) {
    Copy-Item $versionJsonSrc (Join-Path $GhPagesWorktree 'version.json') -Force
}

$pagesDeploy = Join-Path $GhPagesWorktree '.pages-deploy'
$stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
Set-Content -Path $pagesDeploy -Value "downloads-index-v$Version`nrebuilt=$stamp" -NoNewline

git add "downloads/v$Version" downloads/index.html download.html .pages-deploy
$status = git status --porcelain
if (-not $status) {
    Write-Host 'Downloads unchanged on gh-pages.' -ForegroundColor Yellow
    exit 0
}

git commit -m "Deploy v$Version download packages to GitHub Pages"
git config http.postBuffer 524288000
git push origin gh-pages --no-verify
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Downloads deployed:' -ForegroundColor Green
Write-Host '  https://rgsneddon.github.io/evolve/downloads/'
Get-ChildItem $dstDir -File | ForEach-Object {
    if ($_.Extension -ne '.sha256') {
        Write-Host "  https://rgsneddon.github.io/evolve/downloads/v$Version/$($_.Name)"
    }
}