# Enables Windows Developer Mode (required for Flutter Windows desktop plugin symlinks).
# Must be run as Administrator.

$ErrorActionPreference = 'Stop'
$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'

if (-not (Test-Path $path)) {
    New-Item -Path $path -Force | Out-Null
}

Set-ItemProperty -Path $path -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord -Force
Write-Host 'Developer Mode registry flag enabled.'
Write-Host 'If Settings still shows it off, toggle Developer Mode once in:'
Write-Host '  Settings -> Privacy & security -> For developers -> Developer Mode'