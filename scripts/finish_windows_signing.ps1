# One-shot: diagnose signing readiness, sign, verify, re-stage downloads.
param(
    [string]$Version = '',
    [switch]$SkipBuild,
    [switch]$AllowUnsigned
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$scratch = $env:EVOLVE_SIGNING_SCRATCH
if (-not $scratch) {
    $scratch = Join-Path $env:TEMP 'evolve-signing-finish'
}
New-Item -ItemType Directory -Path $scratch -Force | Out-Null

. "$PSScriptRoot\lib\code_sign.ps1"
. "$PSScriptRoot\lib\azure_trusted_signing.ps1"
. "$PSScriptRoot\lib\release_signing_status.ps1"

Set-Location $Root

$logPath = Join-Path $scratch 'signing_build.log'
$transcriptStarted = $false
try {
    Start-Transcript -Path $logPath -Force | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Host "Note: could not open transcript at $logPath ($($_.Exception.Message))" -ForegroundColor Yellow
}
try {
    Write-Host '=== Finish Windows signing ===' -ForegroundColor Cyan

    $readiness = Test-WindowsSigningReadiness -Root $Root
    if (-not $readiness.Ready -and $readiness.Backend -eq 'azure') {
        $metaPath = Join-Path $Root 'tools\trusted-signing\metadata.json'
        $probe = Get-AzureTrustedSigningProbe -Root $Root -MetadataPath $metaPath
        Write-Host "Azure logged in: $($probe.LoggedIn) user=$($probe.User)" -ForegroundColor Cyan
        foreach ($b in $probe.Blockers) { Write-Host "  Azure: $b" -ForegroundColor Yellow }

        if ($probe.LoggedIn -and -not $probe.SecurityDefaults -and $probe.Profiles.Count -gt 0) {
            Ensure-AzureTrustedSigningMetadata -Root $Root -MetadataPath $metaPath | Out-Null
            $readiness = Test-WindowsSigningReadiness -Root $Root
        }
    }

    Assert-WindowsSigningReadiness -Root $Root

    if ($SkipBuild) {
        & "$PSScriptRoot\complete_code_signing.ps1" -SignOnly -Version $Version
    } else {
        & "$PSScriptRoot\build_windows_installer.ps1" -Version $Version
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if (-not $Version -and $pubspec -match 'version:\s*([0-9.]+)\+') {
        $Version = $Matches[1]
    }

    $releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
    $setupPath = Join-Path $Root "build\downloads\v$Version\evolve-v$Version-windows-x64-setup.exe"

    & "$PSScriptRoot\verify_windows_signatures.ps1" -ReleaseDir $releaseDir *> (Join-Path $scratch 'signing_verify_run1.log')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Test-Path $setupPath) {
        & "$PSScriptRoot\verify_windows_signatures.ps1" -ReleaseDir (Split-Path $setupPath -Parent) *> (Join-Path $scratch 'signing_verify_run2.log')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    & "$PSScriptRoot\sync_downloads_signing_copy.ps1" -Version $Version
    if (-not $AllowUnsigned) {
        Assert-PublishReleaseSigningGate -Root $Root -Version $Version
    }

    Write-Host ''
    Write-Host 'Windows signing complete.' -ForegroundColor Green
    Write-Host "  Setup: $setupPath"
    Write-Host "  Logs: $scratch"
} finally {
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
}
exit 0