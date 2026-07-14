# Release signing gate — publish path must sign by default and fail without credentials.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'scripts\lib\code_sign.ps1')
. (Join-Path $Root 'scripts\lib\android_sign.ps1')

$publishScript = Get-Content (Join-Path $Root 'scripts\publish_github_release.ps1') -Raw
if ($publishScript -match 'build_installers\.ps1"\s+-SkipWindowsBuild\s+-SkipApkBuild\s+-SkipDeploy\s+-SkipCodeSign') {
    throw 'publish_github_release.ps1 must not hard-code -SkipCodeSign on build_installers'
}
if ($publishScript -notmatch 'installerArgs\.SkipCodeSign') {
    throw 'publish_github_release.ps1 must only pass SkipCodeSign via explicit installerArgs when requested'
}
if ($publishScript -notmatch 'Assert-ReleaseSigningCredentials') {
    throw 'publish_github_release.ps1 must call Assert-ReleaseSigningCredentials'
}
if ($publishScript -notmatch 'release_signing_status\.ps1') {
    throw 'publish_github_release.ps1 must dot-source release_signing_status.ps1'
}
if ($publishScript -notmatch 'Assert-PublishReleaseSigningGate') {
    throw 'publish_github_release.ps1 must call Assert-PublishReleaseSigningGate'
}

$buildInstallers = Get-Content (Join-Path $Root 'scripts\build_installers.ps1') -Raw
if ($buildInstallers -notmatch 'Assert-ReleaseSigningCredentials') {
    throw 'build_installers.ps1 must gate on Assert-ReleaseSigningCredentials'
}

$gradle = Get-Content (Join-Path $Root 'android\app\build.gradle.kts') -Raw
if ($gradle -notmatch 'signingConfigs') {
    throw 'android/app/build.gradle.kts must define release signingConfigs'
}
if ($gradle -notmatch 'if \(keystorePropertiesFile\.exists\(\)\)') {
    throw 'release signing must be conditional on android/key.properties'
}

if (Test-CodeSignCredentialsConfigured -Root $Root) {
    Write-Host 'Windows signing credentials: configured' -ForegroundColor Green
} else {
    Write-Host 'Windows signing credentials: not configured (expected in CI/dev)' -ForegroundColor Yellow
}

if (Test-AndroidReleaseKeystoreConfigured -Root $Root) {
    Write-Host 'Android release keystore: configured' -ForegroundColor Green
} else {
    Write-Host 'Android release keystore: not configured (expected in CI/dev)' -ForegroundColor Yellow
}

$caught = $false
try {
    Assert-ReleaseSigningCredentials -Root $Root
} catch {
    $caught = $true
    if ("$_" -notmatch 'Release signing credentials are required') {
        throw "Unexpected Assert-ReleaseSigningCredentials error: $_"
    }
}
if (-not $caught -and -not (Test-CodeSignCredentialsConfigured -Root $Root) -and -not (Test-AndroidReleaseKeystoreConfigured -Root $Root)) {
    throw 'Assert-ReleaseSigningCredentials should throw when credentials are missing'
}

Write-Host 'release_signing_gate_test PASS' -ForegroundColor Green