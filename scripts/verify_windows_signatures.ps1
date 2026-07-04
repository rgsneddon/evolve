# Verify Authenticode signatures on Windows release binaries and installer.
param(
    [string]$ReleaseDir = '',
    [string]$InstallerPath = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"

if (-not $ReleaseDir) {
    $ReleaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
}

$paths = @()
if (Test-Path $ReleaseDir) {
    $paths += Get-PeFilesInDirectory -Directory $ReleaseDir | ForEach-Object { $_.FullName }
}

if ($InstallerPath) {
    if (Test-Path $InstallerPath) { $paths += $InstallerPath }
} else {
    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
        $version = $Matches[1]
        $candidate = Join-Path $Root "build\downloads\v$version\evolve-v$version-windows-x64-setup.exe"
        if (Test-Path $candidate) { $paths += $candidate }
    }
}

if (-not $paths) {
    throw 'No PE files found to verify. Build Windows first.'
}

$signTool = Find-SignTool
$failed = 0

Write-Host '=== Authenticode verification ===' -ForegroundColor Cyan
foreach ($path in $paths) {
    $result = Test-AuthenticodeTrustedSignature -FilePath $path -SignTool $signTool
    if ($result.Valid) {
        Write-Host "OK  $path" -ForegroundColor Green
        Write-Host "    $($result.Signer)" -ForegroundColor DarkGray
    } else {
        Write-Host "FAIL $path" -ForegroundColor Red
        Write-Host "    $($result.Message)" -ForegroundColor Red
        $failed++
    }
}

if ($failed -gt 0) {
    throw "$failed file(s) are not signed with a trusted Authenticode certificate."
}

Write-Host ''
Write-Host 'All signatures valid.' -ForegroundColor Green