# Preflight Windows Authenticode signing readiness (JSON + non-zero exit when not ready).
param(
    [switch]$JsonOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"
. "$PSScriptRoot\lib\azure_trusted_signing.ps1"

$readiness = Test-WindowsSigningReadiness -Root $Root
$metaPath = Join-Path $Root 'tools\trusted-signing\metadata.json'
$azureProbe = $null
if ($readiness.Backend -eq 'azure') {
    $azureProbe = Get-AzureTrustedSigningProbe -Root $Root -MetadataPath $metaPath
}

$allBlockers = [System.Collections.Generic.List[string]]::new()
foreach ($b in $readiness.Blockers) { $allBlockers.Add($b) }
if ($azureProbe) {
    foreach ($b in $azureProbe.Blockers) {
        if ($allBlockers -notcontains $b) { $allBlockers.Add($b) }
    }
}

$payload = @{
    ready    = ($allBlockers.Count -eq 0)
    backend  = $readiness.Backend
    blockers = $allBlockers.ToArray()
    envPath  = (Join-Path $Root 'code_sign.local.env')
    azure    = if ($azureProbe) {
        @{
            loggedIn         = $azureProbe.LoggedIn
            user             = $azureProbe.User
            securityDefaults = $azureProbe.SecurityDefaults
            accountName      = $azureProbe.AccountName
            resourceGroup    = $azureProbe.ResourceGroup
            profiles         = $azureProbe.Profiles
        }
    } else { $null }
    probedUtc = (Get-Date).ToUniversalTime().ToString('o')
}

if ($JsonOnly) {
    $payload | ConvertTo-Json -Depth 4
} else {
    Write-Host '=== Windows signing readiness ===' -ForegroundColor Cyan
    Write-Host "Backend: $($readiness.Backend)" -ForegroundColor $(if ($payload.ready) { 'Green' } else { 'Yellow' })
    if ($azureProbe) {
        Write-Host "Azure login: $(if ($azureProbe.LoggedIn) { $azureProbe.User } else { 'no' })" -ForegroundColor Cyan
        if ($azureProbe.Profiles.Count -gt 0) {
            Write-Host "Profiles: $($azureProbe.Profiles -join ', ')" -ForegroundColor Cyan
        }
    }
    if ($payload.ready) {
        Write-Host 'Ready: yes' -ForegroundColor Green
    } else {
        Write-Host 'Ready: no' -ForegroundColor Red
        foreach ($blocker in $allBlockers) {
            Write-Host "  - $blocker" -ForegroundColor Red
        }
        Write-Host ''
        Write-Host 'Fix options:' -ForegroundColor Yellow
        Write-Host '  1. PFX (recommended): scripts\setup_pfx_signing.ps1 -PfxPath <cert.pfx> -PfxPassword <password>'
        Write-Host '     Purchase OV cert: DigiCert, Sectigo, or SSL.com (UK individuals supported)'
        Write-Host '  2. Store: install OV/EV cert in Current User\Personal, set CODE_SIGN_MODE=store'
        Write-Host '  3. SignPath (applied): see .signpath/SETUP.txt — enable SIGNPATH_ENABLED after approval'
    }
    Write-Host ''
    $payload | ConvertTo-Json -Depth 4
}

if (-not $payload.ready) { exit 1 }
exit 0