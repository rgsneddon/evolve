# Android versionCode monotonicity gate — must fail on downgrade candidates, pass on fix.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'scripts\version_utils.ps1')

$maxPrior = Get-MaxPublishedAndroidBuild -Root $Root -ExcludeReleaseVersion '4.0.4'
if ($maxPrior -lt 148) {
    throw "Expected max prior Android build >= 148 (v4.0.3); got $maxPrior"
}

$broken = Test-AndroidVersionCodeMonotonic -Root $Root -CandidateBuild 3 -ReleaseVersion '4.0.4'
if ($broken.Ok) {
    throw 'Guard should reject versionCode 3 (downgrade vs prior published builds)'
}

$fixed = Test-AndroidVersionCodeMonotonic -Root $Root -CandidateBuild 149 -ReleaseVersion '4.0.4'
if (-not $fixed.Ok) {
    throw "Guard should accept versionCode 149 (max prior $maxPrior)"
}

$pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
if ($pubspec -notmatch 'version:\s*4\.0\.4\+149') {
    throw 'pubspec.yaml must be 4.0.4+149 for Android upgrade path'
}

Write-Host "android_versioncode_guard_test PASS (maxPrior=$maxPrior, reject=3, accept=149)" -ForegroundColor Green