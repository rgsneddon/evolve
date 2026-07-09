# Republish fixed v4.0.4 Android APK + checksums to GitHub Releases and sync gh-pages version.json.
param(
    [string]$EvidenceDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib\github.ps1')

$tag = 'v4.0.4'
$version = '4.0.4'
$owner = Get-GitHubOwner -Root $Root
$repo = "$owner/evolve"
$apkDir = Join-Path $Root "build\downloads\v$version"
$apk = Join-Path $apkDir "evolve-v$version-android-setup.apk"
$sha256 = "$apk.sha256"
$sha512 = "$apk.sha512"

if (-not (Test-Path $apk)) {
    throw "Missing fixed APK: $apk (run scripts\build_android_installer.ps1 first)"
}

$env:GH_TOKEN = Get-GitHubToken

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
gh release view $tag --repo $repo 2>$null | Out-Null
$releaseExists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $prevEap
if (-not $releaseExists) {
    throw "GitHub release $tag not found on $repo"
}

$uploadAssets = @($apk)
foreach ($sidecar in @($sha256, $sha512)) {
    if (Test-Path $sidecar) { $uploadAssets += $sidecar }
}

Write-Host "Uploading fixed Android assets to $repo release $tag ..." -ForegroundColor Cyan
& gh release upload $tag --repo $repo --clobber @uploadAssets
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Test-Path (Join-Path $Root 'build\web\index.html')) {
    & (Join-Path $PSScriptRoot 'deploy_web_ghpages.ps1') -Version $version
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host 'Skipping full gh-pages web deploy (no build/web); syncing version.json only.' -ForegroundColor Yellow
    $deployDir = Join-Path (Split-Path $Root -Parent) 'evolve_deploy'
    Copy-Item (Join-Path $Root 'version.json') (Join-Path $deployDir 'version.json') -Force
    Copy-Item (Join-Path $Root 'downloads\index.html') (Join-Path $deployDir 'downloads\index.html') -Force
    Push-Location $deployDir
    try {
        git add version.json downloads/index.html
        $status = git status --porcelain
        if ($status) {
            git commit -m "Sync v4.0.4 version.json build 149 for Android upgrade fix"
            git push origin gh-pages --no-verify
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    } finally {
        Pop-Location
    }
}

if ($EvidenceDir) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    @(
        "republish_tag=$tag"
        "repo=$repo"
        "apk=$apk"
        "uploaded=$($uploadAssets -join ', ')"
        "timestamp=$(Get-Date -Format o)"
    ) | Set-Content (Join-Path $EvidenceDir 'republish_android.log')
}

Write-Host 'Republish complete.' -ForegroundColor Green