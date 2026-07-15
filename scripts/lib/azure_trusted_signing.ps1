# Azure Trusted Signing helpers (metadata discovery, CLI probes).

function Test-AzureMetadataPlaceholders {
    param([string]$MetadataPath)

    if (-not (Test-Path $MetadataPath)) {
        return $true
    }
    $meta = Get-Content $MetadataPath -Raw | ConvertFrom-Json
    $account = [string]$meta.CodeSigningAccountName
    $profile = [string]$meta.CertificateProfileName
    return ($account -match 'YOUR_') -or ($profile -match 'YOUR_')
}

function Find-AzureCli {
    $candidates = @(
        'az',
        "${env:ProgramFiles}\Microsoft SDKs\Azure\CLI2\wbin\az.cmd",
        "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -eq 'az') {
            $cmd = Get-Command az -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
        } elseif (Test-Path $candidate) {
            return $candidate
        }
    }
    return $null
}

function Invoke-AzureCli {
    param(
        [Parameter(Mandatory = $true)][string]$Az,
        [Parameter(Mandatory = $true)][string[]]$Args,
        [switch]$AllowFailure
    )

    $output = & $Az @Args --only-show-errors 2>&1
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

function Get-AzureTrustedSigningProbe {
    param(
        [string]$Root = '',
        [string]$MetadataPath = ''
    )

    $blockers = [System.Collections.Generic.List[string]]::new()
    $AzExe = Find-AzureCli
    if (-not $AzExe) {
        $blockers.Add('Azure CLI not installed.')
        return [PSCustomObject]@{
            LoggedIn           = $false
            SecurityDefaults   = $null
            AccountName        = ''
            ResourceGroup      = ''
            Profiles           = @()
            IdentityValidation = $null
            Blockers           = $blockers.ToArray()
        }
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $acctJson = ''
    try {
        $rawAcct = & $AzExe account show -o json --only-show-errors 2>&1
        if ($null -eq $rawAcct) { $acctJson = '' } else { $acctJson = [string]$rawAcct }
        $acctJson = $acctJson.Trim()
    } finally {
        $ErrorActionPreference = $prevEap
    }

    $loggedIn = $false
    $user = ''
    if ($acctJson -and $acctJson.StartsWith('{')) {
        $acct = $acctJson | ConvertFrom-Json
        $loggedIn = $true
        $user = $acct.user.name
    } else {
        $blockers.Add('Azure CLI not logged in (run: az login).')
    }

    $accountName = 'evrgs'
    $resourceGroup = 'evolve-codesign-rg'
    if ($MetadataPath -and (Test-Path $MetadataPath)) {
        $meta = Get-Content $MetadataPath -Raw | ConvertFrom-Json
        if ($meta.CodeSigningAccountName -and $meta.CodeSigningAccountName -notmatch 'YOUR_') {
            $accountName = $meta.CodeSigningAccountName
        }
    }

    $securityDefaults = $null
    $profiles = @()
    if ($loggedIn) {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $listExit = 0
        $listOut = ''
        try {
            $rawList = & $AzExe trustedsigning certificate-profile list `
                --account-name $accountName `
                --resource-group $resourceGroup `
                -o json --only-show-errors 2>&1
            if ($null -eq $rawList) { $listOut = '' } else { $listOut = [string]$rawList }
            $listOut = $listOut.Trim()
            $listExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prevEap
        }
        if ($listOut -match 'AADSTS530035') {
            $securityDefaults = $true
            $blockers.Add('Azure AD security defaults block Trusted Signing API (AADSTS530035). Disable in Entra ID > Properties > Manage security defaults.')
        } elseif ($listExit -ne 0 -and $listOut) {
            $blockers.Add("Azure profile list failed: $listOut")
        } elseif ($listOut -match '^\s*\[') {
            if ($listOut -ne '[]') {
                $profiles = @($listOut | ConvertFrom-Json | ForEach-Object { $_.profileName })
            } else {
                $blockers.Add("No certificate profiles on account '$accountName'. Complete identity validation in Azure Portal, then create a Public Trust profile.")
            }
        }
    }

    return [PSCustomObject]@{
        LoggedIn           = $loggedIn
        User               = $user
        SecurityDefaults   = $securityDefaults
        AccountName        = $accountName
        ResourceGroup      = $resourceGroup
        Profiles           = $profiles
        Blockers           = $blockers.ToArray()
    }
}

function Ensure-AzureTrustedSigningMetadata {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$MetadataPath = ''
    )

    $Az = Find-AzureCli
    if (-not $Az) {
        throw 'Azure CLI not found. Install: winget install -e --id Microsoft.AzureCLI'
    }

    if (-not $MetadataPath) {
        $MetadataPath = Join-Path $Root 'tools\trusted-signing\metadata.json'
    }

    $meta = Get-Content $MetadataPath -Raw | ConvertFrom-Json
    $needsMeta = Test-AzureMetadataPlaceholders -MetadataPath $MetadataPath
    if (-not $needsMeta) {
        return [PSCustomObject]@{
            MetadataPath = $MetadataPath
            AccountName  = $meta.CodeSigningAccountName
            ProfileName  = $meta.CertificateProfileName
            Updated      = $false
        }
    }

    $acct = & $Az account show 2>$null | ConvertFrom-Json
    if (-not $acct) {
        Write-Host 'Azure login required...' -ForegroundColor Yellow
        Invoke-AzureCli -Az $Az -Args @('login', '--use-device-code')
        $acct = Invoke-AzureCli -Az $Az -Args @('account', 'show') | ConvertFrom-Json
    }
    Write-Host "Azure: $($acct.user.name) ($($acct.name))" -ForegroundColor Green

    $extList = [string](& $Az extension list --query "[?name=='trustedsigning'].name" -o tsv --only-show-errors 2>$null)
    if (-not $extList.Trim()) {
        Invoke-AzureCli -Az $Az -Args @('extension', 'add', '--name', 'trustedsigning', '--allow-preview', 'true', '--yes') -AllowFailure
    }

    $accountsJson = [string](& $Az trustedsigning list -o json --only-show-errors 2>$null).Trim()
    $accounts = if ($accountsJson -match '^\s*\[') {
        if ($accountsJson -eq '[]') { @() } else { $accountsJson | ConvertFrom-Json }
    } else {
        @()
    }
    if (-not $accounts -or $accounts.Count -eq 0) {
        $rg = 'evolve-codesign-rg'
        $rgExists = [string](Invoke-AzureCli -Az $Az -Args @('group', 'exists', '--name', $rg))
        if ($rgExists.Trim().ToLowerInvariant() -ne 'true') {
            Invoke-AzureCli -Az $Az -Args @('group', 'create', '--name', $rg, '--location', 'eastus') | Out-Null
        }
        $createOut = ''
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $createOut = (& $Az trustedsigning create -n evolve-codesign -g $rg -l eastus --sku Basic -o json 2>&1 | Out-String).Trim()
        } finally {
            $ErrorActionPreference = $prevEap
        }
        if ($createOut -match 'free, trial or sponsored') {
            throw @'
Azure Trusted Signing is not available on free, trial, or sponsored subscriptions.

Upgrade to a paid Azure subscription or use PFX mode (scripts\setup_pfx_signing.ps1).
'@
        }
        if ($LASTEXITCODE -eq 0 -and $createOut) {
            $accounts = $createOut | ConvertFrom-Json
            $accounts = @($accounts)
        } else {
            throw 'No Azure Trusted Signing account found. Create one in Azure Portal, then re-run.'
        }
    }

    $account = $accounts | Select-Object -First 1
    $accountName = $account.name
    $rg = $account.id -replace '.*/resourceGroups/([^/]+)/.*', '$1'

    $profiles = Invoke-AzureCli -Az $Az -Args @(
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
        Endpoint               = $endpoint
        CodeSigningAccountName = $accountName
        CertificateProfileName = $profile.profileName
    } | ConvertTo-Json | Set-Content -Path $MetadataPath -Encoding utf8

    Write-Host "metadata.json updated: $accountName / $($profile.profileName)" -ForegroundColor Green
    return [PSCustomObject]@{
        MetadataPath = $MetadataPath
        AccountName  = $accountName
        ProfileName  = $profile.profileName
        Updated      = $true
    }
}