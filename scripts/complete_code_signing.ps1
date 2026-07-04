# One-shot: Azure login, discover Trusted Signing account/profile, sign all PE binaries + installer.
param(
    [string]$Version = '',
    [switch]$SignOnly,
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"

Set-Location $Root

$azCandidates = @(
    'az',
    "${env:ProgramFiles}\Microsoft SDKs\Azure\CLI2\wbin\az.cmd",
    "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
)
$az = $null
foreach ($candidate in $azCandidates) {
    if ($candidate -eq 'az') {
        $cmd = Get-Command az -ErrorAction SilentlyContinue
        if ($cmd) { $az = $cmd.Source; break }
    } elseif (Test-Path $candidate) {
        $az = $candidate
        break
    }
}
if (-not $az) {
    throw 'Azure CLI not found. Install: winget install -e --id Microsoft.AzureCLI'
}

function Invoke-Az {
    param(
        [string[]]$Args,
        [switch]$AllowFailure
    )
    $output = & $az @Args --only-show-errors 2>&1
    if ($output -is [System.Management.Automation.ErrorRecord]) {
        $msg = $output.Exception.Message
        if ($AllowFailure) { return $msg }
        throw $msg
    }
    if (-not $AllowFailure -and $LASTEXITCODE -ne 0) {
        throw "az $($Args -join ' ') failed ($LASTEXITCODE): $output"
    }
    return $output
}

$acct = & $az account show 2>$null | ConvertFrom-Json
if (-not $acct) {
    Write-Host 'Azure login required...' -ForegroundColor Yellow
    Invoke-Az @('login', '--use-device-code')
    $acct = Invoke-Az @('account', 'show') | ConvertFrom-Json
}
Write-Host "Azure: $($acct.user.name) ($($acct.name))" -ForegroundColor Green

$extList = [string](& $az extension list --query "[?name=='trustedsigning'].name" -o tsv --only-show-errors 2>$null)
if (-not $extList.Trim()) {
    Invoke-Az @('extension', 'add', '--name', 'trustedsigning', '--allow-preview', 'true', '--yes') -AllowFailure
}

$metaPath = Join-Path $Root 'tools\trusted-signing\metadata.json'
$meta = Get-Content $metaPath -Raw | ConvertFrom-Json
$needsMeta = ($meta.CodeSigningAccountName -match 'YOUR_') -or ($meta.CertificateProfileName -match 'YOUR_')

if ($needsMeta) {
    $accountsJson = [string](& $az trustedsigning list -o json --only-show-errors 2>$null).Trim()
    $accounts = if ($accountsJson -match '^\s*\[') {
        if ($accountsJson -eq '[]') { @() } else { $accountsJson | ConvertFrom-Json }
    } else {
        @()
    }
    if (-not $accounts -or $accounts.Count -eq 0) {
        $rg = 'evolve-codesign-rg'
        $rgExists = [string](Invoke-Az @('group', 'exists', '--name', $rg))
        if ($rgExists.Trim().ToLowerInvariant() -ne 'true') {
            Invoke-Az @('group', 'create', '--name', $rg, '--location', 'eastus') | Out-Null
        }
        $createOut = ''
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $createOut = (& $az trustedsigning create -n evolve-codesign -g $rg -l eastus --sku Basic -o json 2>&1 | Out-String).Trim()
        } finally {
            $ErrorActionPreference = $prevEap
        }
        if ($createOut -match 'free, trial or sponsored') {
            throw @'
Azure Trusted Signing is not available on free, trial, or sponsored subscriptions.

To sign with Azure Trusted Signing:
  1. Upgrade to a paid Azure subscription (Pay-As-You-Go)
  2. Create an Artifact Signing account in Azure Portal:
     https://portal.azure.com/#view/Microsoft_Azure_CodeSigning/CodeSigningMenuBlade/~/overview
  3. Complete identity validation (portal only; 1-20 business days for individuals)
  4. Create a Public Trust certificate profile, then re-run:
     scripts\complete_code_signing.ps1

Alternative: purchase an OV/EV code-signing .pfx (DigiCert, Sectigo, SSL.com),
set CODE_SIGN_MODE=pfx in code_sign.local.env, then run:
  scripts\build_windows_installer.ps1
'@
        }
        if ($LASTEXITCODE -eq 0 -and $createOut) {
            $accounts = $createOut | ConvertFrom-Json
            $accounts = @($accounts)
        } else {
            throw @'
No Azure Trusted Signing account found in this subscription.

Create one in Azure Portal:
  https://portal.azure.com/#view/Microsoft_Azure_CodeSigning/CodeSigningMenuBlade/~/overview

Complete identity validation (1-20 business days for individuals), then create a certificate profile.
Re-run: scripts\complete_code_signing.ps1
'@
        }
    }

    $account = $accounts | Select-Object -First 1
    $accountName = $account.name
    $rg = $account.id -replace '.*/resourceGroups/([^/]+)/.*', '$1'

    $profiles = Invoke-Az @(
        'trustedsigning', 'certificate-profile', 'list',
        '--account-name', $accountName,
        '--resource-group', $rg,
        '-o', 'json'
    ) | ConvertFrom-Json

    if (-not $profiles -or $profiles.Count -eq 0) {
        throw "Trusted Signing account '$accountName' has no certificate profiles. Create one in Azure Portal."
    }

    $profile = $profiles | Select-Object -First 1
    $endpoint = if ($account.location -eq 'westus') {
        'https://wus.codesigning.azure.net'
    } elseif ($account.location -eq 'centralus') {
        'https://cus.codesigning.azure.net'
    } else {
        'https://eus.codesigning.azure.net'
    }

    @{
        Endpoint                 = $endpoint
        CodeSigningAccountName   = $accountName
        CertificateProfileName   = $profile.profileName
    } | ConvertTo-Json | Set-Content -Path $metaPath -Encoding utf8

    Write-Host "metadata.json updated: $accountName / $($profile.profileName)" -ForegroundColor Green
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