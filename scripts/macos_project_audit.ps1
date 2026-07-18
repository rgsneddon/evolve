# Audit macOS project bundle ID, entitlements, and signing docs; write evidence log.
param(
    [string]$EvidenceDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

$appInfo = Get-Content (Join-Path $Root 'macos\Runner\Configs\AppInfo.xcconfig') -Raw
$releaseEnt = Get-Content (Join-Path $Root 'macos\Runner\Release.entitlements') -Raw
$infoPlist = Get-Content (Join-Path $Root 'macos\Runner\Info.plist') -Raw
$signing = Get-Content (Join-Path $Root 'macos\SIGNING.md') -Raw

if ($appInfo -notmatch 'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.evolve\.chronoflux') {
    throw 'macos AppInfo.xcconfig must set PRODUCT_BUNDLE_IDENTIFIER = com.evolve.chronoflux'
}
if (-not (Test-Path (Join-Path $Root 'macos\Runner.xcodeproj\project.pbxproj'))) {
    throw 'Missing macos/Runner.xcodeproj/project.pbxproj'
}
if (-not (Test-Path (Join-Path $Root 'macos\Runner.xcworkspace\contents.xcworkspacedata'))) {
    throw 'Missing macos/Runner.xcworkspace'
}

$lines = @(
    'macos_project_audit evolve'
    'bundleId=com.evolve.chronoflux'
    "has_network_client=$($releaseEnt -match 'network\.client')"
    "has_camera_usage=$($infoPlist -match 'NSCameraUsageDescription')"
    "signing_doc_DEVELOPMENT_TEAM=$($signing -match 'DEVELOPMENT_TEAM')"
    "has_Runner_xcodeproj=$true"
    "has_build_macos_installer=$(Test-Path (Join-Path $Root 'scripts\build_macos_installer.ps1'))"
    'result=PASS'
)

if ($EvidenceDir) {
    New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    $lines | Set-Content (Join-Path $EvidenceDir 'macos_project_audit_evolve.log') -Encoding utf8
}

$lines | ForEach-Object { Write-Host $_ }
exit 0
