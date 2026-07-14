# Release signing status probes must match downloads copy.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'scripts\lib\release_signing_status.ps1')

$status = Get-ReleaseSigningStatus -Root $Root -Version '4.1.5'
Write-Host "v4.1.5 Windows Authenticode: $($status.WindowsAuthenticodeSigned)" -ForegroundColor Cyan
Write-Host "v4.1.5 Android release signed: $($status.AndroidReleaseSigned)" -ForegroundColor Cyan

if ($status.WindowsAuthenticodeSigned) {
    throw 'Expected v4.1.5 Windows setup to be unsigned in current environment (audit baseline)'
}
if (-not $status.AndroidReleaseSigned) {
    throw "Expected v4.1.5 Android APK to be release-signed; $($status.AndroidMessage)"
}

$manifest = Write-ReleaseSigningStatusManifest -Root $Root -Version '4.1.5'
$manifestPath = Join-Path $manifest.VersionDir 'signing-status.json'
if (-not (Test-Path $manifestPath)) {
    throw 'signing-status.json was not written'
}

Update-DownloadsInstallNotesForSigning -Root $Root -Version '4.1.5' | Out-Null
$index = Get-Content (Join-Path $Root 'downloads\index.html') -Raw
if ($index -notmatch 'SmartScreen may ask you to confirm') {
    throw 'downloads index must warn about SmartScreen when Windows is unsigned'
}
if ($index -match 'Authenticode-signed for a trusted install path') {
    throw 'downloads index must not claim trusted Authenticode path while unsigned'
}
if ($index -notmatch 'release-key signed|Evolve release key') {
    throw 'downloads index must note Android release-key signing when APK is release-signed'
}

Write-Host 'release_signing_status_test PASS' -ForegroundColor Green