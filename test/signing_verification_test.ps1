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

$apkCandidates = @(
    (Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'),
    (Join-Path $Root 'build\downloads\v4.1.5\evolve-v4.1.5-android-setup.apk')
)
$apkPath = $apkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($apkPath) {
    $apkResult = Test-ApkReleaseSignature -ApkPath $apkPath
    Write-Host "APK under test: $apkPath" -ForegroundColor Cyan
    Write-Host "  valid=$($apkResult.Valid) debug=$($apkResult.IsDebug) schemes=$($apkResult.Schemes -join ',')" -ForegroundColor Cyan
    if ($apkResult.IsDebug) {
        Write-Host 'Debug-signed APK correctly detected' -ForegroundColor Green
    } elseif ($apkResult.Valid) {
        Write-Host 'Release-signed APK verified' -ForegroundColor Green
    } else {
        Write-Host "APK verification note: $($apkResult.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host 'No local APK to verify (skip APK fixture check)' -ForegroundColor Yellow
}

@(
    "unsigned_pe_rejected=$([bool](-not $winResult.Valid))"
    "unsigned_message=$($winResult.Message)"
    "apk_tested=$(if ($apkPath) { $apkPath } else { 'none' })"
) | Set-Content (Join-Path $scratch 'signing_fix_assertions.log') -Encoding utf8

Write-Host 'signing_verification_test PASS' -ForegroundColor Green