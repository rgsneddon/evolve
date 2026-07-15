# Unit tests for Test-WindowsSigningReadiness (fixture env files, no network).
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'scripts\lib\code_sign.ps1')

$scratch = Join-Path $env:TEMP "evolve-signing-readiness-test-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $scratch -Force | Out-Null

function New-FixtureEnv {
    param([string]$Name, [string[]]$Lines)
    $path = Join-Path $scratch $Name
    $Lines | Set-Content -Path $path -Encoding utf8
    return $path
}

try {
    $pfxPath = Join-Path $scratch 'fixture.pfx'
    'dummy' | Set-Content -Path $pfxPath -Encoding ascii

    $missing = Test-WindowsSigningReadiness -Root $scratch -EnvPath (Join-Path $scratch 'missing.env')
    if ($missing.Ready) { throw 'missing env should not be ready' }
    if ($missing.Blockers.Count -lt 1) { throw 'missing env should report blockers' }

    $pfxEnv = New-FixtureEnv 'pfx.env' @(
        'CODE_SIGN_MODE=pfx'
        "CODE_SIGN_PFX_PATH=$pfxPath"
        'CODE_SIGN_PFX_PASSWORD=secret'
    )
    $pfxReady = Test-WindowsSigningReadiness -Root $scratch -EnvPath $pfxEnv
    if (-not $pfxReady.Ready) {
        throw "valid pfx fixture should be ready: $($pfxReady.Blockers -join '; ')"
    }
    if ($pfxReady.Backend -ne 'pfx') { throw 'backend should be pfx' }

    $pfxPlaceholder = New-FixtureEnv 'pfx-bad.env' @(
        'CODE_SIGN_MODE=pfx'
        "CODE_SIGN_PFX_PATH=$pfxPath"
        'CODE_SIGN_PFX_PASSWORD=your_pfx_password'
    )
    $pfxBad = Test-WindowsSigningReadiness -Root $scratch -EnvPath $pfxPlaceholder
    if ($pfxBad.Ready) { throw 'placeholder password should not be ready' }
    if ($pfxBad.Blockers -notmatch 'placeholder') { throw 'should flag placeholder password' }

    $azureMeta = Join-Path $scratch 'metadata.json'
    @{
        Endpoint               = 'https://eus.codesigning.azure.net'
        CodeSigningAccountName = 'evrgs'
        CertificateProfileName = 'YOUR_PROFILE_NAME'
    } | ConvertTo-Json | Set-Content -Path $azureMeta -Encoding utf8

    $dlib = Join-Path $scratch 'Azure.CodeSigning.Dlib.dll'
    'dll' | Set-Content -Path $dlib -Encoding ascii

    $azureEnv = New-FixtureEnv 'azure.env' @(
        'CODE_SIGN_MODE=azure'
        "AZURE_CODESIGN_DLIB_PATH=$dlib"
        "AZURE_CODESIGN_METADATA_PATH=$azureMeta"
    )
    $azureBad = Test-WindowsSigningReadiness -Root $scratch -EnvPath $azureEnv
    if ($azureBad.Ready) { throw 'azure placeholder profile should not be ready' }
    if ($azureBad.Blockers -notmatch 'YOUR_PROFILE_NAME|placeholder') {
        throw "azure blockers should mention placeholder profile: $($azureBad.Blockers -join '; ')"
    }

    @{
        Endpoint               = 'https://eus.codesigning.azure.net'
        CodeSigningAccountName = 'evrgs'
        CertificateProfileName = 'evolve-public-trust'
    } | ConvertTo-Json | Set-Content -Path $azureMeta -Encoding utf8

    $azureGood = Test-WindowsSigningReadiness -Root $scratch -EnvPath $azureEnv
    if (-not $azureGood.Ready) {
        throw "azure with valid metadata should be ready (offline): $($azureGood.Blockers -join '; ')"
    }

    $caught = $false
    try {
        Assert-WindowsSigningReadiness -Root $scratch
    } catch {
        $caught = $true
        if ("$_" -notmatch 'not ready') { throw "unexpected assert error: $_" }
    }
    if (-not $caught) { throw 'Assert-WindowsSigningReadiness should throw when not ready' }

    Write-Host 'windows_signing_readiness_test PASS' -ForegroundColor Green
} finally {
    Remove-Item -Path $scratch -Recurse -Force -ErrorAction SilentlyContinue
}