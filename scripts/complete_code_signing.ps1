# One-shot: Azure login, discover Trusted Signing account/profile, sign all PE binaries + installer.
param(
    [string]$Version = '',
    [switch]$SignOnly,
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"
. "$PSScriptRoot\lib\azure_trusted_signing.ps1"

Set-Location $Root

$metaPath = Join-Path $Root 'tools\trusted-signing\metadata.json'
$readiness = Test-WindowsSigningReadiness -Root $Root
if (-not $readiness.Ready -and $readiness.Backend -eq 'azure') {
    $probe = Get-AzureTrustedSigningProbe -Root $Root -MetadataPath $metaPath
    if ($probe.LoggedIn -and -not $probe.SecurityDefaults -and $probe.Profiles.Count -gt 0) {
        Ensure-AzureTrustedSigningMetadata -Root $Root -MetadataPath $metaPath | Out-Null
        $readiness = Test-WindowsSigningReadiness -Root $Root
    } elseif ($probe.LoggedIn -and $probe.Profiles.Count -eq 0) {
        throw @"
Azure Trusted Signing account '$($probe.AccountName)' has no certificate profiles.

Complete identity validation in Azure Portal, then run:
  scripts\setup_azure_trusted_signing.ps1 -IdentityValidationId <guid> -OpenPortal
  scripts\finish_windows_signing.ps1 -SkipBuild

$($readiness.Blockers -join [Environment]::NewLine)
"@
    }
}
if (-not $readiness.Ready) {
    Assert-WindowsSigningReadiness -Root $Root
}

if (-not $SignOnly) {
    & "$PSScriptRoot\build_windows_installer.ps1" -Version $Version
    exit $LASTEXITCODE
}

$releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
Sign-WindowsPeBinaries -Directory $releaseDir -Root $Root

$pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
    if (-not $Version) { $Version = $Matches[1] }
}
$setupPath = Join-Path $Root "build\installer\windows\evolve-v$Version-windows-x64-setup.exe"
if (Test-Path $setupPath) {
    $signTool = Find-SignTool
    $signConfig = Get-CodeSignConfig -Root $Root
    Sign-AuthenticodeFile -FilePath $setupPath -Config $signConfig -SignTool $signTool | Out-Null
}

& "$PSScriptRoot\verify_windows_signatures.ps1" -ReleaseDir $releaseDir
if (Test-Path $setupPath) {
    & "$PSScriptRoot\verify_windows_signatures.ps1" -ReleaseDir (Split-Path $setupPath -Parent)
}
exit $LASTEXITCODE