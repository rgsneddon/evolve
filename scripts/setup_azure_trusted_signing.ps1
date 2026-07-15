# Finish Azure Trusted Signing setup: create certificate profile, update metadata.json.
param(
    [string]$IdentityValidationId = '',
    [string]$ProfileName = 'evolve-public-trust',
    [string]$AccountName = 'evrgs',
    [string]$ResourceGroup = 'evolve-codesign-rg',
    [switch]$OpenPortal,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"
. "$PSScriptRoot\lib\azure_trusted_signing.ps1"

Set-Location $Root

$metaPath = Join-Path $Root 'tools\trusted-signing\metadata.json'
$portalUrl = "https://portal.azure.com/#resource/subscriptions/fa8820f2-7a78-42c1-bee1-312c3b8229f4/resourceGroups/$ResourceGroup/providers/Microsoft.CodeSigning/codeSigningAccounts/$AccountName/identityValidations"

Write-Host '=== Azure Trusted Signing setup ===' -ForegroundColor Cyan

$probe = Get-AzureTrustedSigningProbe -Root $Root -MetadataPath $metaPath
Write-Host "Azure login: $(if ($probe.LoggedIn) { $probe.User } else { 'no' })" -ForegroundColor Cyan
Write-Host "Account: $AccountName ($ResourceGroup)" -ForegroundColor Cyan

if (-not $probe.LoggedIn) {
    Write-Host 'Run: az login' -ForegroundColor Yellow
    if (-not $CheckOnly) {
        $AzExe = Find-AzureCli
        if ($AzExe) { & $AzExe login }
    }
    $probe = Get-AzureTrustedSigningProbe -Root $Root -MetadataPath $metaPath
    if (-not $probe.LoggedIn) { throw 'Azure CLI login required.' }
}

if ($probe.Profiles.Count -gt 0) {
    Write-Host "Existing profiles: $($probe.Profiles -join ', ')" -ForegroundColor Green
    Ensure-AzureTrustedSigningMetadata -Root $Root -MetadataPath $metaPath | Out-Null
    if ($CheckOnly) { exit 0 }
    Write-Host 'metadata.json is ready. Run: scripts\finish_windows_signing.ps1' -ForegroundColor Green
    exit 0
}

if (-not $IdentityValidationId) {
    $envPath = Join-Path $Root 'code_sign.local.env'
    if (Test-Path $envPath) {
        Import-CodeSignLocalEnv -Root $Root | Out-Null
        if ($env:AZURE_CODESIGN_IDENTITY_VALIDATION_ID) {
            $IdentityValidationId = $env:AZURE_CODESIGN_IDENTITY_VALIDATION_ID.Trim()
        }
    }
}

if (-not $IdentityValidationId) {
    Write-Host ''
    Write-Host 'No certificate profiles and no identity validation ID.' -ForegroundColor Yellow
    Write-Host 'Identity validation must be completed in Azure Portal (not CLI).' -ForegroundColor Yellow
    Write-Host 'UK developers: use Organization -> Public Trust (Individual Public Trust is USA/Canada only).' -ForegroundColor Yellow
    Write-Host ''
    Write-Host "Portal: $portalUrl" -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'After validation status is Completed, copy Identity validation Id from the portal blade, then:' -ForegroundColor Yellow
    Write-Host "  scripts\setup_azure_trusted_signing.ps1 -IdentityValidationId <guid> -ProfileName $ProfileName"
    Write-Host 'Or set AZURE_CODESIGN_IDENTITY_VALIDATION_ID in code_sign.local.env'
    if ($OpenPortal) { Start-Process $portalUrl }
    exit 1
}

if ($CheckOnly) {
    Write-Host "Would create profile '$ProfileName' with validation id $IdentityValidationId" -ForegroundColor Cyan
    exit 0
}

$AzExe = Find-AzureCli
Write-Host "Creating certificate profile '$ProfileName' (validation id: $IdentityValidationId)..." -ForegroundColor Cyan
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$createOut = & $AzExe artifact-signing certificate-profile create `
    --account-name $AccountName `
    --resource-group $ResourceGroup `
    -n $ProfileName `
    --profile-type PublicTrust `
    --identity-validation-id $IdentityValidationId `
    -o json 2>&1
$createExit = $LASTEXITCODE
if ($createExit -ne 0) {
    $createOut = & $AzExe trustedsigning certificate-profile create `
        --account-name $AccountName `
        --resource-group $ResourceGroup `
        -n $ProfileName `
        --profile-type PublicTrust `
        --identity-validation-id $IdentityValidationId `
        -o json 2>&1
    $createExit = $LASTEXITCODE
}
$ErrorActionPreference = $prevEap

if ($createExit -ne 0) {
    $msg = [string]$createOut
    if ($msg -match 'identity validation') {
        Write-Host ''
        Write-Host 'Azure could not find this identity validation id in the current tenant/subscription.' -ForegroundColor Yellow
        Write-Host 'Check in Portal (evrgs -> Identity validations):' -ForegroundColor Yellow
        Write-Host '  - Status must be Completed (not In Progress or Action Required)' -ForegroundColor Yellow
        Write-Host '  - Copy Identity validation Id from the entity detail blade (not the URL)' -ForegroundColor Yellow
        Write-Host '  - UK: use Organization -> Public Trust (Individual Public Trust is USA/Canada only)' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Portal workaround: create the certificate profile in Portal instead:' -ForegroundColor Cyan
        Write-Host "  $portalUrl" -ForegroundColor Cyan
        Write-Host "  evrgs -> Certificate profiles -> Create -> Public Trust -> name: $ProfileName" -ForegroundColor Cyan
        Write-Host '  Then re-run: scripts\setup_azure_trusted_signing.ps1 -CheckOnly' -ForegroundColor Cyan
    }
    throw "Certificate profile create failed ($createExit): $createOut"
}

$account = az trustedsigning show --name $AccountName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
$endpoint = if ($account.location -eq 'westus') {
    'https://wus.codesigning.azure.net'
} elseif ($account.location -eq 'centralus') {
    'https://cus.codesigning.azure.net'
} else {
    'https://eus.codesigning.azure.net'
}

@{
    Endpoint               = $endpoint
    CodeSigningAccountName = $AccountName
    CertificateProfileName = $ProfileName
} | ConvertTo-Json | Set-Content -Path $metaPath -Encoding utf8

Write-Host "metadata.json updated: $AccountName / $ProfileName" -ForegroundColor Green
$readiness = Test-WindowsSigningReadiness -Root $Root
if (-not $readiness.Ready) {
    throw "Signing still not ready: $($readiness.Blockers -join '; ')"
}

Write-Host 'Azure Trusted Signing is ready. Run: scripts\finish_windows_signing.ps1' -ForegroundColor Green
exit 0