# Evolve — one-shot Flutter multi-platform build tooling setup (Windows host).
# Run in an elevated PowerShell for Developer Mode; other steps use winget/user scope.

$ErrorActionPreference = 'Continue'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"

Write-Host '=== Evolve build tooling setup ===' -ForegroundColor Cyan

function Test-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (Test-Admin) {
    Write-Host 'Enabling Developer Mode...'
    & "$PSScriptRoot\enable_developer_mode.ps1"
} else {
    Write-Host 'Skipping Developer Mode (re-run as Administrator), or enable manually in Settings.' -ForegroundColor Yellow
}

Write-Host 'Installing OpenJDK 17 (if missing)...'
winget install -e --id Microsoft.OpenJDK.17 --accept-package-agreements --accept-source-agreements

Write-Host 'Installing Visual Studio 2022 Build Tools + C++ workload (if missing)...'
winget install -e --id Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

Write-Host 'Setting up Android command-line SDK...'
& "$PSScriptRoot\setup_android_sdk.ps1"

Write-Host 'Persisting build environment...'
& "$PSScriptRoot\configure_build_env.ps1" -Persist

Write-Host ''
Write-Host 'Running flutter doctor...'
& "$PSScriptRoot\doctor.ps1"

Write-Host ''
Write-Host 'Build commands:' -ForegroundColor Green
Write-Host "  cd $Root"
Write-Host '  .\scripts\build.ps1 web'
Write-Host '  .\scripts\build.ps1 windows'
Write-Host '  .\scripts\build.ps1 apk'
Write-Host '  .\scripts\build_all.ps1'