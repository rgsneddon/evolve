# Configure PFX Authenticode signing and verify the certificate chain.
param(
    [string]$PfxPath = '',
    [string]$PfxPassword = '',
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"

Set-Location $Root

$secretsDir = Join-Path $Root '.secrets'
$defaultPfx = Join-Path $secretsDir 'evolve-codesign.pfx'
$envPath = Join-Path $Root 'code_sign.local.env'

if (-not (Test-Path $envPath)) {
    Copy-Item (Join-Path $Root 'code_sign.local.env.example') $envPath
}

if ($PfxPath) {
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
    if ($PfxPath -ne $defaultPfx) {
        Copy-Item $PfxPath $defaultPfx -Force
    }
    $content = Get-Content $envPath -Raw
    if ($content -notmatch '(?m)^CODE_SIGN_MODE=pfx') {
        $content = $content -replace 'CODE_SIGN_MODE=azure', 'CODE_SIGN_MODE=pfx'
    }
    if ($content -notmatch '(?m)^CODE_SIGN_PFX_PATH=') {
        $content += "`nCODE_SIGN_PFX_PATH=$defaultPfx`n"
    } else {
        $content = $content -replace '(?m)^CODE_SIGN_PFX_PATH=.*', "CODE_SIGN_PFX_PATH=$defaultPfx"
    }
    if ($PfxPassword) {
        if ($content -match '(?m)^CODE_SIGN_PFX_PASSWORD=') {
            $content = $content -replace '(?m)^CODE_SIGN_PFX_PASSWORD=.*', "CODE_SIGN_PFX_PASSWORD=$PfxPassword"
        } else {
            $content += "CODE_SIGN_PFX_PASSWORD=$PfxPassword`n"
        }
    }
    if ($content -notmatch '(?m)^CODE_SIGN_TIMESTAMP_URL=') {
        $content += "CODE_SIGN_TIMESTAMP_URL=http://timestamp.digicert.com`n"
    }
    Set-Content -Path $envPath -Value $content.TrimEnd() -Encoding utf8
    Write-Host "Updated $envPath" -ForegroundColor Green
}

if (-not (Test-Path $defaultPfx)) {
    Write-Host ''
    Write-Host 'No PFX found yet.' -ForegroundColor Yellow
    Write-Host "Place your certificate at: $defaultPfx" -ForegroundColor Cyan
    Write-Host 'Then set CODE_SIGN_PFX_PASSWORD in code_sign.local.env and re-run.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Purchase OV code signing (UK individuals supported):' -ForegroundColor Yellow
    Write-Host '  DigiCert:  https://www.digicert.com/signing/code-signing-certificates'
    Write-Host '  Sectigo:   https://www.sectigo.com/ssl-certificates-tls/code-signing'
    Write-Host '  SSL.com:   https://www.ssl.com/code-signing/'
    Write-Host ''
    Write-Host 'Free for open source (CI signing, not local PFX):' -ForegroundColor Yellow
    Write-Host '  SignPath:  https://signpath.org/apply'
    Write-Host ''
    Write-Host 'After issuance, export as .pfx with private key, then:' -ForegroundColor Yellow
    Write-Host "  scripts\setup_pfx_signing.ps1 -PfxPath C:\path\to\cert.pfx -PfxPassword 'your-password'"
    exit 1
}

try {
    $config = Get-CodeSignConfig -Root $Root
    if ($config.Mode -ne 'pfx') { throw "CODE_SIGN_MODE must be pfx (currently $($config.Mode))" }
    if (-not $config.PfxPassword -or $config.PfxPassword -match 'REPLACE_WITH') {
        throw 'Set CODE_SIGN_PFX_PASSWORD in code_sign.local.env'
    }
    $signTool = Find-SignTool
    Write-Host "signtool: $signTool" -ForegroundColor Green
    Write-Host "PFX: $($config.PfxPath)" -ForegroundColor Green

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $config.PfxPath, $config.PfxPassword,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    )
    Write-Host "Certificate subject: $($cert.Subject)" -ForegroundColor Green
    Write-Host "Issuer: $($cert.Issuer)" -ForegroundColor Green
    Write-Host "NotAfter: $($cert.NotAfter)" -ForegroundColor Green
    $cert.Dispose()
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

if ($CheckOnly) { exit 0 }

$releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $releaseDir 'evolve.exe'))) {
    Write-Host 'Windows release build not found. Run: scripts\build_windows_installer.ps1' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host 'Signing release binaries and building installer...' -ForegroundColor Cyan
& "$PSScriptRoot\build_windows_installer.ps1"
exit $LASTEXITCODE