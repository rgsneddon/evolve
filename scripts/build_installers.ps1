# Build versioned Windows setup.exe and Android APK packages, then deploy to GitHub Pages.
param(
    [switch]$SkipWindowsBuild,
    [switch]$SkipApkBuild,
    [switch]$SkipIosBuild,
    [switch]$SkipDeploy,
    [switch]$SkipCodeSign
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\ios_build.ps1"
Set-Location $Root

& "$PSScriptRoot\build_windows_installer.ps1" @PSBoundParameters
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& "$PSScriptRoot\build_android_installer.ps1" @PSBoundParameters
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$skipIosEffective = $SkipIosBuild
if (-not $skipIosEffective -and -not (Test-IosBuildHost)) {
    Write-Host 'Skipping iOS IPA compile on non-macOS host (requires Xcode).' -ForegroundColor Yellow
    $skipIosEffective = $true
}
if (-not $skipIosEffective) {
    & "$PSScriptRoot\build_ios_installer.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} elseif (Get-FlutterIpaSource -Root $Root) {
    & "$PSScriptRoot\build_ios_installer.ps1" -SkipIosBuild
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& "$PSScriptRoot\sign_download_packages.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipDeploy) {
    & "$PSScriptRoot\deploy_downloads.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ''
Write-Host 'All installers built.' -ForegroundColor Green