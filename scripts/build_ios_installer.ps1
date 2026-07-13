# Build a versioned iOS IPA package with SHA-256/SHA-512 checksum sidecars.
param(
    [string]$Version = '',
    [string]$Build = '',
    [switch]$SkipIosBuild,
    [string]$ProductPrefix = 'evolve',
    [string]$PagesBaseUrl = 'https://rgsneddon.github.io/evolve/downloads'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"
. "$PSScriptRoot\lib\ios_build.ps1"
. "$PSScriptRoot\lib\package_checksum.ps1"

Set-Location $Root

if (-not $Version -or -not $Build) {
    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
        if (-not $Version) { $Version = $Matches[1] }
        if (-not $Build) { $Build = $Matches[2] }
    } else {
        throw 'Could not read version from pubspec.yaml'
    }
}

$publishedName = "$ProductPrefix-v$Version-ios-setup.ipa"
$stagingDir = Join-Path $Root 'build\installer\ios'
$versionedDir = Join-Path $Root "build\downloads\v$Version"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $versionedDir -Force | Out-Null
$publishedPath = Join-Path $versionedDir $publishedName

if (-not $SkipIosBuild) {
    if (-not (Test-IosBuildHost)) {
        throw @"
iOS IPA build requires macOS with Xcode (flutter build ipa).
This Windows host cannot compile IPAs. Re-run on a Mac or CI macos-latest, or pass -SkipIosBuild after staging an IPA at:
  build\ios\ipa\*.ipa
"@
    }
    $info = Set-BuildEnvironment
    Invoke-FlutterIpaBuild -Root $Root -FlutterExe $info.FlutterExe
}

$ipaSrc = Get-FlutterIpaSource -Root $Root
if (-not $ipaSrc) {
    throw "Missing iOS release IPA. Run flutter build ipa on macOS or pass -SkipIosBuild with a staged IPA."
}

$stagingPath = Join-Path $stagingDir $publishedName
Copy-Item $ipaSrc $stagingPath -Force
Copy-Item $stagingPath $publishedPath -Force

$sizeMb = [math]::Round((Get-Item $publishedPath).Length / 1MB, 1)
$secureUrl = "$PagesBaseUrl/v$Version/$publishedName"
$releaseUrl = "https://github.com/rgsneddon/$ProductPrefix/releases/download/v$Version/$publishedName"

$signed = Write-PackageChecksumSidecar `
    -PackagePath $publishedPath `
    -Version $Version `
    -Build $Build `
    -Platform 'ios' `
    -Url $releaseUrl `
    -ExtraMetadata @('bundleId=com.evolve.chronoflux')

$installerMetaDir = Join-Path $Root 'installer\ios'
New-Item -ItemType Directory -Path $installerMetaDir -Force | Out-Null
$manifestPath = Join-Path $installerMetaDir "$ProductPrefix-v$Version-ios.json"
@{
    name = $publishedName
    version = $Version
    build = $Build
    platform = 'ios'
    bundleId = 'com.evolve.chronoflux'
    sizeBytes = (Get-Item $publishedPath).Length
    sizeMb = $sizeMb
    sha256 = $signed.Sha256
    sha512 = $signed.Sha512
    url = $releaseUrl
    pagesUrl = $secureUrl
} | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding utf8

Write-VersionChecksumManifest -VersionDir $versionedDir -BaseUrl "https://github.com/rgsneddon/$ProductPrefix/releases/download/v$Version" | Out-Null

Write-Host ''
Write-Host "iOS installer v$Version (build $Build) ready:" -ForegroundColor Green
Write-Host "  $publishedPath"
Write-Host "  $($signed.Sha256Path)"
Write-Host "  Size: $sizeMb MB"
Write-Host "  Release URL: $releaseUrl"
exit 0