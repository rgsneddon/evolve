# Audit iOS project bundle ID, permissions, and signing placeholders; write evidence log.
param(
    [string]$EvidenceDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

$pbxproj = Get-Content (Join-Path $Root 'ios\Runner.xcodeproj\project.pbxproj') -Raw
$infoPlist = Get-Content (Join-Path $Root 'ios\Runner\Info.plist') -Raw
$signing = Get-Content (Join-Path $Root 'ios\SIGNING.md') -Raw
$exportPlist = Get-Content (Join-Path $Root 'ios\ExportOptions.plist') -Raw

$bundleMatch = [regex]::Match($pbxproj, 'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
if (-not $bundleMatch.Success) { throw 'Missing PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj' }
$bundleId = $bundleMatch.Groups[1].Value.Trim()

$lines = @(
    'ios_project_audit evolve'
    "bundleId=$bundleId"
    "has_NSCameraUsageDescription=$($infoPlist -match 'NSCameraUsageDescription')"
    "has_NSFaceIDUsageDescription=$($infoPlist -match 'NSFaceIDUsageDescription')"
    "export_method_development=$($exportPlist -match '<string>development</string>')"
    "signing_style_automatic=$($exportPlist -match '<string>automatic</string>')"
    "signing_doc_DEVELOPMENT_TEAM=$($signing -match 'DEVELOPMENT_TEAM')"
    'required_apple_inputs=Apple Developer Program, Team ID, distribution cert, provisioning profile'
    'result=PASS'
)

if ($EvidenceDir) {
    New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    $lines | Set-Content (Join-Path $EvidenceDir 'ios_project_audit_evolve.log') -Encoding utf8
}

$lines | ForEach-Object { Write-Host $_ }
exit 0