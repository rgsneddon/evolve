# Keep gh-pages download landing pages in sync without wiping versioned packages.
# gh-pages carries checksum manifests only; full installers live on GitHub Releases.

function Invoke-GitCommand {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Command,
        [Parameter(Mandatory = $true)][string]$FailureMessage
    )

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Command 2>&1 | Out-Null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($exitCode -ne 0) {
        throw "$FailureMessage (exit $exitCode)"
    }
}

function Sync-GhPagesBranch {
    param(
        [string]$Branch = 'gh-pages',
        [string]$Remote = 'origin'
    )

    Invoke-GitCommand { git fetch $Remote $Branch } "git fetch $Remote $Branch failed"

    $tracking = "$Remote/$Branch"
    $current = git branch --show-current 2>$null
    if ($current -eq $Branch) {
        Invoke-GitCommand { git reset --hard $tracking } "git reset --hard $tracking failed"
    } elseif (git show-ref --verify --quiet "refs/heads/$Branch") {
        Invoke-GitCommand { git checkout -f $Branch } "git checkout -f $Branch failed"
        Invoke-GitCommand { git reset --hard $tracking } "git reset --hard $tracking failed"
    } elseif (git show-ref --verify --quiet "refs/remotes/$tracking") {
        Invoke-GitCommand { git checkout -B $Branch $tracking } "git checkout -B $Branch failed"
    } else {
        Invoke-GitCommand { git checkout --orphan $Branch } "git checkout --orphan $Branch failed"
        git rm -rf . 2>$null | Out-Null
    }
}

function Get-GhPagesChecksumArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$StagedDir
    )

    Get-ChildItem $StagedDir -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in '.sha256', '.sha512', '.json' -or $_.Name -like 'CHECKSUMS*'
    }
}

function Sync-GhPagesDownloads {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$DeployDir,
        [string]$Version = ''
    )

    $downloadsSrc = Join-Path $Root 'downloads'
    if (-not (Test-Path $downloadsSrc)) { return }

    $downloadsDst = Join-Path $DeployDir 'downloads'
    if (-not (Test-Path $downloadsDst)) {
        New-Item -ItemType Directory -Path $downloadsDst -Force | Out-Null
    }

    foreach ($name in @('index.html', 'ssucf_framework_workings.txt')) {
        $src = Join-Path $downloadsSrc $name
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $downloadsDst $name) -Force
        }
    }

    if (-not $Version) {
        $pubspec = Join-Path $Root 'pubspec.yaml'
        if (Test-Path $pubspec) {
            $pub = Get-Content $pubspec -Raw
            if ($pub -match 'version:\s*([0-9.]+)\+(\d+)') {
                $Version = $Matches[1]
            }
        }
    }
    if (-not $Version) { return }

    $stagedDir = Join-Path $Root "build\downloads\v$Version"
    if (-not (Test-Path $stagedDir)) { return }

    $versionDst = Join-Path $downloadsDst "v$Version"
    New-Item -ItemType Directory -Path $versionDst -Force | Out-Null

    foreach ($bin in @('*-android-setup.apk', '*-windows-x64-setup.exe')) {
        Get-ChildItem $versionDst -Filter $bin -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item $_.FullName -Force
        }
    }

    Get-GhPagesChecksumArtifacts -StagedDir $stagedDir | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $versionDst $_.Name) -Force
    }
}