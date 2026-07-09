# Audit Flutter and perc_chain dependencies before release.
param(
    [string]$LogPath = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib\dependency_audit.ps1')
Set-Location $Root

Invoke-DependencyAudit -Root $Root -LogPath $LogPath | Out-Null
Write-Host 'Dependency audit passed.' -ForegroundColor Green