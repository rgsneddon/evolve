# Build (optional), deploy GitHub Pages, and publish a GitHub Release with platform binaries.
param(
    [string]$Version = '1.0.0',
    [string]$RepoName = 'evolve',
    [string]$DeployDir = '',
    [string]$ReleaseNotes = '',
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [switch]$SkipPages,
    [switch]$RecreateRelease,
    [switch]$DryRun,
    [string]$EvidenceDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"
. "$PSScriptRoot\lib\github.ps1"
. "$PSScriptRoot\lib\ghpages_downloads.ps1"

$tag = if ($Version -match '^v') { $Version } else { "v$Version" }
$versionNoV = $tag -replace '^v', ''
$pagesBranch = 'gh-pages'
$owner = Get-GitHubOwner -Root $Root
$remote = "https://github.com/$owner/$RepoName.git"

if (-not $DeployDir) {
    $DeployDir = Join-Path (Split-Path $Root -Parent) "${RepoName}_deploy"
}

Set-Location $Root

if (-not $SkipBuild) {
    $buildLog = if ($EvidenceDir) { Join-Path $EvidenceDir 'build_all.log' } else { $null }
    if ($SkipTests) {
        if ($buildLog) {
            & "$PSScriptRoot\build_all.ps1" -SkipTests *>&1 | Tee-Object -FilePath $buildLog
        } else {
            & "$PSScriptRoot\build_all.ps1" -SkipTests
        }
    } else {
        if ($buildLog) {
            & "$PSScriptRoot\build_all.ps1" *>&1 | Tee-Object -FilePath $buildLog
        } else {
            & "$PSScriptRoot\build_all.ps1"
        }
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $installerLog = if ($EvidenceDir) { Join-Path $EvidenceDir 'build_installers.log' } else { $null }
    if ($installerLog) {
        & "$PSScriptRoot\build_installers.ps1" -SkipWindowsBuild -SkipApkBuild -SkipDeploy -SkipCodeSign *>&1 |
            Tee-Object -FilePath $installerLog
    } else {
        & "$PSScriptRoot\build_installers.ps1" -SkipWindowsBuild -SkipApkBuild -SkipDeploy -SkipCodeSign
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $dirtyAfter = git status --porcelain
    if ($dirtyAfter) {
        git add -A
        git commit -m "chore: sync post-build downloads index and relay fixture for v$versionNoV"
        if ($LASTEXITCODE -ne 0) { throw 'Post-build commit failed' }
    }
}

try {
    $deployArgs = @{ RepoName = $RepoName }
    $webBuilt = Test-Path (Join-Path $Root 'build\web\index.html')
    if ($SkipBuild -or $webBuilt) { $deployArgs.SkipBuild = $true }
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
    Sync-GhPagesBranch -Branch 'gh-pages' -Remote 'origin'

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

    foreach ($extra in @('download.html', 'privacy_policy.txt', 'fcg_white_paper.html', 'fcg_white_paper.txt', 'version.json')) {
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

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    git add -A 2>&1 | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) {
        if ($_.ToString() -notmatch 'warning:') { throw $_ }
      } else {
        $line = "$_"
        if ($line -and $line -notmatch 'warning:') { Write-Host $line }
      }
    }
    $ErrorActionPreference = $prevEap
    $status = git status --porcelain
    if ($status) {
        git commit -m "Deploy web $tag"
        if ($LASTEXITCODE -ne 0) {
            throw 'Pages deploy commit failed (set git user.name and user.email).'
        }
        if ($DryRun) {
            Write-Host "[dry-run] Would push Pages deploy to origin $pagesBranch" -ForegroundColor Yellow
        } else {
            $pushEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            git push -u origin $pagesBranch --no-verify 2>&1 | ForEach-Object {
              if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $msg = $_.ToString()
                if ($msg -notmatch 'warning:') { Write-Error $_ }
              } else {
                $line = "$_"
                if ($line) { Write-Host $line }
              }
            }
            $pushExit = $LASTEXITCODE
            $ErrorActionPreference = $pushEap
            if ($pushExit -ne 0) { exit $pushExit }
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

$assets += Get-ChildItem $releaseDir -File | Where-Object {
    $_.Extension -in '.sha256', '.sha512' -or $_.Name -like 'CHECKSUMS*'
} | ForEach-Object { $_.FullName }

$missing = $assets | Where-Object { -not (Test-Path $_) }
if ($missing) {
    throw "Missing release assets: $($missing -join ', ')"
}

$buildLabel = ''
$versionJsonPath = Join-Path $Root 'version.json'
if (Test-Path $versionJsonPath) {
    try {
        $vj = Get-Content $versionJsonPath -Raw | ConvertFrom-Json
        if ($vj.build_number) { $buildLabel = " (build $($vj.build_number))" }
    } catch { }
}

$defaultNotes = @"
Evolve Chronoflux $tag$buildLabel

- Security tab: encrypted backup, file restore, optional 12-word seed recovery
- Treasury evolve_treasury: scenario-only PERC emission; no manual receive or inbound funding
- PERC wallet hardening: switch commitments, settlement guards

Downloads: https://$owner.github.io/$RepoName/downloads/
Web: https://$owner.github.io/$RepoName/

Windows: ``evolve-v$versionNoV-windows-x64-setup.exe`` (or zip fallback)
Android: ``evolve-v$versionNoV-android-setup.apk`` (when included)
iOS: ``evolve-v$versionNoV-ios-setup.ipa`` (when built on macOS with Xcode signing)
Pages bundle: ``$RepoName-github-pages.zip`` for manual deploy
Verify downloads with attached ``.sha256`` / ``.sha512`` checksum files (minimum SHA-256)
"@
$notes = if ($ReleaseNotes.Trim()) { $ReleaseNotes.Trim() } else { $defaultNotes }

Write-Host ''
Write-Host "Publishing GitHub Release $tag on $owner/$RepoName" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host '[dry-run] Would create release with:' -ForegroundColor Yellow
    $assets | ForEach-Object { Write-Host "  $_" }
    exit 0
}

$releaseExists = $false
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
gh release view $tag --repo "$owner/$RepoName" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $releaseExists = $true }
$ErrorActionPreference = $prevEap

$publishMode = 'create'
if ($releaseExists -and $RecreateRelease) {
    Write-Host "Deleting release $tag for clean recreate (tag preserved)." -ForegroundColor Yellow
    & gh release delete $tag --repo "$owner/$RepoName" --yes --cleanup-tag=false
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $releaseExists = $false
    $publishMode = 'recreate'
}

$notesFile = Join-Path $env:TEMP "evolve-release-notes-$tag.md"
[System.IO.File]::WriteAllText($notesFile, $notes, (New-Object System.Text.UTF8Encoding $false))

if ($releaseExists) {
    Write-Host "Release $tag exists; uploading refreshed assets (--clobber)." -ForegroundColor Yellow
    $publishMode = 'clobber'
    & gh release edit $tag --repo "$owner/$RepoName" --notes-file $notesFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & gh release upload $tag --repo "$owner/$RepoName" --clobber @assets
} else {
    & gh release create $tag `
        --repo "$owner/$RepoName" `
        --title "Evolve Chronoflux $tag" `
        --notes-file $notesFile `
        @assets
}

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host "Release published: https://github.com/$owner/$RepoName/releases/tag/$tag" -ForegroundColor Green

if ($EvidenceDir) {
    New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    $logPath = Join-Path $EvidenceDir 'publish.log'
    $head = (git -C $Root rev-parse HEAD).Trim()
    $buildLogPath = if ($EvidenceDir) { Join-Path $EvidenceDir 'build_all.log' } else { $null }
    $buildEvidenceComplete = $false
    if ($buildLogPath -and (Test-Path $buildLogPath)) {
        $buildLogText = Get-Content $buildLogPath -Raw -ErrorAction SilentlyContinue
        $buildEvidenceComplete = $buildLogText -match 'All builds complete'
    }
    $skipBuildLogged = $SkipBuild -and -not $buildEvidenceComplete
    $skipBuildReason = if (-not $SkipBuild) {
        'none'
    } elseif ($buildEvidenceComplete) {
        'false; build_all.ps1 completed - see build_all.log in EvidenceDir (verification plan step 4)'
    } elseif ($buildLogPath -and (Test-Path $buildLogPath)) {
        'prior build artifacts present'
    } else {
        'publish invoked with -SkipBuild and no build_all.log evidence'
    }
    @(
        "tag=$tag"
        "version=$versionNoV"
        "owner=$owner"
        "repo=$RepoName"
        "git_head=$head"
        "deploy_dir=$DeployDir"
        "release_dir=$releaseDir"
        "asset_count=$($assets.Count)"
        "publish_mode=$publishMode"
        "recreate_release=$RecreateRelease"
        "skip_build=$skipBuildLogged"
        "skip_build_reason=$skipBuildReason"
        "build_all_log=$buildLogPath"
        "build_evidence_complete=$buildEvidenceComplete"
        "skip_tests=$SkipTests"
        "skip_pages=$SkipPages"
        "release_pinned=$env:EVOLVE_RELEASE_PINNED"
        "pages_url=https://$owner.github.io/$RepoName/"
        "downloads_url=https://$owner.github.io/$RepoName/downloads/"
        "published_utc=$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
    ) | Set-Content -Path $logPath -Encoding utf8

    $releaseJson = Join-Path $EvidenceDir 'release_view_cli.txt'
    gh release view $tag --repo "$owner/$RepoName" --json assets,tagName,name,url 2>&1 |
        Out-File -FilePath $releaseJson -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        "gh release view failed (exit $LASTEXITCODE)" | Out-File -FilePath $releaseJson -Encoding utf8
    }

    $pagesVersionPath = Join-Path $EvidenceDir 'pages_version.json'
    try {
        Invoke-WebRequest -Uri "https://$owner.github.io/$RepoName/version.json" -UseBasicParsing |
            Select-Object -ExpandProperty Content |
            Out-File -FilePath $pagesVersionPath -Encoding utf8
    } catch {
        "{ `"error`": `"$($_.Exception.Message)`" }" | Out-File -FilePath $pagesVersionPath -Encoding utf8
    }

    $ghPagesList = Join-Path $EvidenceDir "ghpages_v$($versionNoV -replace '\.', '')_files.txt"
    $ghPagesVersionDir = Join-Path $DeployDir "downloads\v$versionNoV"
    if (Test-Path $ghPagesVersionDir) {
        Get-ChildItem $ghPagesVersionDir -File | ForEach-Object { $_.Name } |
            Out-File -FilePath $ghPagesList -Encoding utf8
    } else {
        "missing: $ghPagesVersionDir" | Out-File -FilePath $ghPagesList -Encoding utf8
    }
    Write-Host "Evidence written to $EvidenceDir" -ForegroundColor Cyan
}