# Build a versioned macOS .app zip with SHA-256/SHA-512 checksum sidecars.
param(
    [string]$Version = '',
    [string]$Build = '',
    [switch]$SkipMacosBuild,
    [string]$ProductPrefix = 'evolve'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"
. "$PSScriptRoot\lib\macos_build.ps1"
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

$publishedName = "$ProductPrefix-v$Version-macos-x64.zip"
$stagingDir = Join-Path $Root 'build\installer\macos'
$versionedDir = Join-Path $Root "build\downloads\v$Version"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $versionedDir -Force | Out-Null
$publishedPath = Join-Path $versionedDir $publishedName

if (-not $SkipMacosBuild) {
    if (-not (Test-MacosBuildHost)) {
        throw @"
macOS app build requires macOS with Xcode (flutter build macos).
This host cannot compile macOS apps. Re-run on a Mac or CI macos-latest, or pass -SkipMacosBuild after staging:
  build/macos/Build/Products/Release/Evolve.app
"@
    }
    $info = Set-BuildEnvironment
    Invoke-FlutterMacosBuild -Root $Root -FlutterExe $info.FlutterExe
}

$appSrc = Get-FlutterMacosAppSource -Root $Root
if (-not $appSrc) {
    throw "Missing macOS release app. Run flutter build macos on macOS or pass -SkipMacosBuild with a staged .app."
}

$stagingZip = Join-Path $stagingDir $publishedName
if (Test-Path $stagingZip) { Remove-Item $stagingZip -Force }
Compress-Archive -Path $appSrc -DestinationPath $stagingZip -Force
Copy-Item $stagingZip $publishedPath -Force

$sizeMb = [math]::Round((Get-Item $publishedPath).Length / 1MB, 1)
$releaseUrl = "https://github.com/rgsneddon/$ProductPrefix/releases/download/v$Version/$publishedName"

$signed = Write-PackageChecksumSidecar `
    -PackagePath $publishedPath `
    -Version $Version `
    -Build $Build `
    -Platform 'macos' `
    -Url $releaseUrl `
    -ExtraMetadata @('bundleId=com.evolve.chronoflux', "appPath=$appSrc")

$installerMetaDir = Join-Path $Root 'installer\macos'
New-Item -ItemType Directory -Path $installerMetaDir -Force | Out-Null
$manifestPath = Join-Path $installerMetaDir "$ProductPrefix-v$Version-macos.json"
@{
    name = $publishedName
    version = $Version
    build = $Build
    platform = 'macos'
    bundleId = 'com.evolve.chronoflux'
    sizeBytes = (Get-Item $publishedPath).Length
    sizeMb = $sizeMb
    sha256 = $signed.Sha256
    sha512 = $signed.Sha512
    url = $releaseUrl
    appSource = $appSrc
} | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding utf8

Write-VersionChecksumManifest -VersionDir $versionedDir -BaseUrl "https://github.com/rgsneddon/$ProductPrefix/releases/download/v$Version" | Out-Null

Write-Host ''
Write-Host "macOS installer v$Version (build $Build) ready:" -ForegroundColor Green
Write-Host "  $publishedPath"
Write-Host "  $($signed.Sha256Path)"
Write-Host "  Size: $sizeMb MB"
Write-Host "  Release URL: $releaseUrl"
exit 0
