# Load (and optionally persist) build environment for Evolve Flutter targets.
param(
    [switch]$Persist
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\env.ps1"

$info = Set-BuildEnvironment -Persist:$Persist

Write-Host '=== Evolve build environment ===' -ForegroundColor Cyan
Write-Host "Flutter:  $($info.FlutterExe)"
Write-Host "JAVA_HOME: $(if ($info.JavaHome) { $info.JavaHome } else { '(not found — run scripts\setup_build_tooling.ps1)' })"
Write-Host "ANDROID:  $($info.AndroidSdk)"
Write-Host "CHROME:   $(if ($info.Edge) { $info.Edge } else { '(Edge not found — web dev may warn)' })"

if (-not $info.JavaHome) {
    Write-Host ''
    Write-Host 'JDK missing. Install with: winget install -e --id Microsoft.OpenJDK.17' -ForegroundColor Yellow
    exit 1
}

if ($Persist) {
    Write-Host ''
    Write-Host 'User environment variables saved. Open a new terminal for them to apply globally.' -ForegroundColor Green
}