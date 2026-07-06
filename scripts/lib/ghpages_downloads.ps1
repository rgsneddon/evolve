# Keep gh-pages download landing pages in sync without wiping versioned packages.

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

    # Landing pages and docs only — never delete existing downloads/v* trees.
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

    # Host checksum sidecars on Pages. Windows setup (~23 MB) is copied for legacy
    # in-app update links; large Android APKs stay on GitHub Releases only.
    Get-ChildItem $stagedDir -File | Where-Object {
        $_.Extension -in '.sha256', '.sha512', '.json' -or
        $_.Name -like 'CHECKSUMS*' -or
        $_.Name -like '*-windows-x64-setup.exe'
    } | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $versionDst $_.Name) -Force
    }
}