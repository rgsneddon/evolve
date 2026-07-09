# Android versionCode monotonicity gate — must fail on downgrade candidates, pass on fix.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'scripts\version_utils.ps1')

$max = Get-MaxPublishedAndroidBuild -Root $Root
if ($max -lt 136) {
    throw "Expected max published Android build >= 136 (v4.0.0 baseline); got $max"
}

$broken = Test-AndroidVersionCodeMonotonic -Root $Root -CandidateBuild 3
if ($broken.Ok) {
    throw 'Guard should reject versionCode 3 (downgrade vs published 136)'
}

$fixedBuild = $max + 1
$fixed = Test-AndroidVersionCodeMonotonic -Root $Root -CandidateBuild $fixedBuild
if (-not $fixed.Ok) {
    throw "Guard should accept versionCode $fixedBuild (max published $max)"
}

$pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
if ($pubspec -notmatch 'version:\s*4\.0\.4\+149') {
    throw 'pubspec.yaml must be 4.0.4+149 for Android upgrade path'
}

Write-Host "android_versioncode_guard_test PASS (max=$max, reject=3, accept=$fixedBuild)" -ForegroundColor Green