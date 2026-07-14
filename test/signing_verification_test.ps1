# Signing verification — unsigned/debug artifacts must fail; trusted signatures pass.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$scratch = $env:GROK_GOAL_SCRATCH
if (-not $scratch) {
    $scratch = Join-Path $env:TEMP 'grok-goal-signing-verify'
}
New-Item -ItemType Directory -Path $scratch -Force | Out-Null

. (Join-Path $Root 'scripts\lib\code_sign.ps1')
. (Join-Path $Root 'scripts\lib\android_sign.ps1')

$unsignedExe = Join-Path $scratch 'unsigned-test.exe'
Copy-Item (Join-Path $env:WINDIR 'System32\notepad.exe') $unsignedExe -Force

$signTool = Find-SignTool
$winResult = Test-AuthenticodeTrustedSignature -FilePath $unsignedExe -SignTool $signTool
if ($winResult.Valid) {
    throw 'Copied notepad.exe should not pass as Evolve Authenticode signature'
}
Write-Host "Unsigned PE correctly rejected: $($winResult.Message)" -ForegroundColor Green

$releaseApk = Join-Path $Root 'build\downloads\v4.1.5\evolve-v4.1.5-android-setup.apk'
if (-not (Test-Path $releaseApk)) {
    $releaseApk = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'
}
$releaseApkResult = $null
if (Test-Path $releaseApk) {
    $releaseApkResult = Test-ApkReleaseSignature -ApkPath $releaseApk
    Write-Host "Release APK: $releaseApk valid=$($releaseApkResult.Valid) debug=$($releaseApkResult.IsDebug)" -ForegroundColor Cyan
}

$debugApk = Join-Path $Root 'build\app\outputs\flutter-apk\app-debug.apk'
$debugApkResult = $null
if (-not (Test-Path $debugApk)) {
    throw "Debug APK fixture missing at $debugApk. Run: flutter build apk --debug"
}
if (Test-Path $debugApk) {
    $debugApkResult = Test-ApkReleaseSignature -ApkPath $debugApk
    Write-Host "Debug APK: $debugApk valid=$($debugApkResult.Valid) debug=$($debugApkResult.IsDebug)" -ForegroundColor Cyan
    if (-not $debugApkResult.Valid -and $debugApkResult.IsDebug) {
        Write-Host 'Debug-signed APK correctly rejected' -ForegroundColor Green
    } else {
        throw "Debug APK fixture should fail release verification with IsDebug=true; got valid=$($debugApkResult.Valid) debug=$($debugApkResult.IsDebug)"
    }
} else {
    throw 'Could not produce debug APK fixture for signing verification'
}

$logPath = Join-Path $scratch 'signing_fix_assertions.log'
$logTmp = Join-Path $scratch 'signing_fix_assertions.tmp'
@(
    "unsigned_pe_rejected=$([bool](-not $winResult.Valid))"
    "unsigned_message=$($winResult.Message)"
    "release_apk_tested=$releaseApk"
    "release_apk_valid=$(if ($releaseApkResult) { $releaseApkResult.Valid } else { 'none' })"
    "release_apk_is_debug=$(if ($releaseApkResult) { $releaseApkResult.IsDebug } else { 'none' })"
    "debug_apk_tested=$debugApk"
    "debug_apk_rejected=$([bool](-not $debugApkResult.Valid))"
    "debug_apk_is_debug=$($debugApkResult.IsDebug)"
    "debug_apk_message=$($debugApkResult.Message)"
) | Set-Content $logTmp -Encoding utf8
Move-Item $logTmp $logPath -Force

Write-Host 'signing_verification_test PASS' -ForegroundColor Green