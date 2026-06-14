# Release-build all platforms available on this Windows host (web, windows, android).
param(
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"

$info = Set-BuildEnvironment
$flutter = $info.FlutterExe

Set-Location $Root

if (-not $SkipTests) {
    Write-Host '=== Running tests ===' -ForegroundColor Cyan
    & $flutter test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$targets = @('web', 'windows')
if ($info.JavaHome) {
    $targets += 'apk'
} else {
    Write-Host 'Skipping Android (JDK not found).' -ForegroundColor Yellow
}

foreach ($target in $targets) {
    Write-Host ''
    Write-Host "=== Building $target ===" -ForegroundColor Cyan
    & "$PSScriptRoot\build.ps1" -Platform $(if ($target -eq 'apk') { 'apk' } else { $target })
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ''
Write-Host '=== All builds complete ===' -ForegroundColor Green
Write-Host '  Web:     build\web'
Write-Host '  Windows: build\windows\x64\runner\Release\evolve.exe'
if ($info.JavaHome) {
    Write-Host '  Android: build\app\outputs\flutter-apk\app-release.apk'
}