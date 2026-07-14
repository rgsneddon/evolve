# Sync downloads install notes with probed artifact signing status.
param(
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\release_signing_status.ps1"

$result = Update-DownloadsInstallNotesForSigning -Root $Root -Version $Version
Write-Host "Windows Authenticode: $($result.Status.WindowsAuthenticodeSigned)" -ForegroundColor $(if ($result.Status.WindowsAuthenticodeSigned) { 'Green' } else { 'Yellow' })
Write-Host "Android release signed: $($result.Status.AndroidReleaseSigned)" -ForegroundColor $(if ($result.Status.AndroidReleaseSigned) { 'Green' } else { 'Yellow' })
Write-Host "  Windows note: $($result.Copy.WindowsNote)" -ForegroundColor Cyan
Write-Host "  Android note: $($result.Copy.AndroidNote)" -ForegroundColor Cyan