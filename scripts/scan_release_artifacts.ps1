# Scan built release installers/APKs for malware before publish.
param(
    [string]$Version = '',
    [string]$VersionDir = '',
    [string]$LogPath = '',
    [switch]$SkipDefender
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib\security_scan.ps1')
Set-Location $Root

Invoke-ReleaseArtifactSecurityScan `
    -Root $Root `
    -Version $Version `
    -VersionDir $VersionDir `
    -ExpectedApkPackage 'com.evolve.chronoflux' `
    -LogPath $LogPath `
    -SkipDefender:$SkipDefender | Out-Null

Write-Host 'Release artifact security scan passed.' -ForegroundColor Green