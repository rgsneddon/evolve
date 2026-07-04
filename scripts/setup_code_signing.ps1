# Prepare Windows Authenticode signing (PFX, cert store, or Azure Trusted Signing).
param(
    [switch]$CheckOnly,
    [switch]$OpenAzurePortal
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"

Set-Location $Root

function Find-AzureCodeSigningDlib {
    $candidates = @(
        (Join-Path $Root 'tools\Microsoft.ArtifactSigning.Client\bin\x64\Azure.CodeSigning.Dlib.dll'),
        (Join-Path $Root 'tools\trusted-signing\x64\Azure.CodeSigning.Dlib.dll'),
        'C:\Program Files\Microsoft\Azure Artifact Signing Client Tools\x64\Azure.CodeSigning.Dlib.dll',
        'C:\Program Files (x86)\Microsoft\Azure Artifact Signing Client Tools\x64\Azure.CodeSigning.Dlib.dll'
    )
    $nugetDir = Join-Path $Root 'tools\Microsoft.ArtifactSigning.Client'
    if (Test-Path $nugetDir) {
        $found = Get-ChildItem $nugetDir -Recurse -Filter 'Azure.CodeSigning.Dlib.dll' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\' } |
            Select-Object -First 1
        if ($found) { $candidates = @($found.FullName) + $candidates }
    }
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Ensure-TrustedSigningTools {
    $toolsDir = Join-Path $Root 'tools\trusted-signing'
    $dlib = Find-AzureCodeSigningDlib
    if ($dlib) {
        Write-Host "Azure Code Signing Dlib: $dlib" -ForegroundColor Green
        return $dlib
    }

    Write-Host 'Installing Azure Artifact Signing Client Tools (winget)...' -ForegroundColor Cyan
    winget install -e --id Microsoft.Azure.ArtifactSigningClientTools `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'winget install failed — download manually from:' -ForegroundColor Yellow
        Write-Host '  https://learn.microsoft.com/azure/artifact-signing/how-to-signing-integrations'
        return $null
    }
    return Find-AzureCodeSigningDlib
}

function Write-AzureMetadataTemplate {
    param([string]$DlibPath)

    $metaDir = Join-Path $Root 'tools\trusted-signing'
    New-Item -ItemType Directory -Path $metaDir -Force | Out-Null
    $metaPath = Join-Path $metaDir 'metadata.json'
    if (-not (Test-Path $metaPath)) {
        @'
{
  "Endpoint": "https://eus.codesigning.azure.net",
  "CodeSigningAccountName": "YOUR_ACCOUNT_NAME",
  "CertificateProfileName": "YOUR_PROFILE_NAME"
}
'@ | Set-Content -Path $metaPath -Encoding utf8
    }

    $envPath = Join-Path $Root 'code_sign.local.env'
    if (-not (Test-Path $envPath)) {
        Copy-Item (Join-Path $Root 'code_sign.local.env.example') $envPath
    }

    $content = Get-Content $envPath -Raw
    $activeLines = ($content -split "`n" | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') }) -join "`n"
    if ($activeLines -notmatch 'CODE_SIGN_MODE=azure') {
        $content = $content -replace 'CODE_SIGN_MODE=pfx', 'CODE_SIGN_MODE=azure'
    }
    if ($DlibPath -and $activeLines -notmatch '(?m)^AZURE_CODESIGN_DLIB_PATH=') {
        $content += "`nAZURE_CODESIGN_DLIB_PATH=$DlibPath`n"
        $content += "AZURE_CODESIGN_METADATA_PATH=$metaPath`n"
        $content += "CODE_SIGN_TIMESTAMP_URL=http://timestamp.acs.microsoft.com`n"
    }
    Set-Content -Path $envPath -Value $content.TrimEnd() -Encoding utf8
    Write-Host "Template metadata: $metaPath" -ForegroundColor Cyan
    Write-Host "Edit code_sign.local.env with your Azure account + profile names." -ForegroundColor Yellow
}

Write-Host '=== Evolve Windows code signing setup ===' -ForegroundColor Cyan

try {
    $signTool = Find-SignTool
    Write-Host "signtool: $signTool" -ForegroundColor Green
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

$envFile = Join-Path $Root 'code_sign.local.env'
if (-not (Test-Path $envFile)) {
    Write-Host ''
    Write-Host 'No code_sign.local.env found.' -ForegroundColor Yellow
    Write-Host 'Choose one path:' -ForegroundColor Yellow
    Write-Host '  A) PFX from DigiCert/Sectigo/SSL.com -> copy code_sign.local.env.example'
    Write-Host '  B) Azure Trusted Signing (recommended) -> run: scripts\setup_code_signing.ps1 -OpenAzurePortal'
    $dlib = Ensure-TrustedSigningTools
    if ($dlib) { Write-AzureMetadataTemplate -DlibPath $dlib }
    if ($OpenAzurePortal) {
        Start-Process 'https://portal.azure.com/#view/Microsoft_Azure_CodeSigning/CodeSigningMenuBlade/~/overview'
    }
    if ($CheckOnly) { exit 1 }
    exit 1
}

try {
    $config = Get-CodeSignConfig -Root $Root
    Write-Host "Signing mode: $($config.Mode)" -ForegroundColor Green
    if ($config.Mode -eq 'azure') {
        if (-not (Test-Path $config.AzureDlib)) {
            throw "Missing Dlib: $($config.AzureDlib)"
        }
        if (-not (Test-Path $config.AzureMeta)) {
            throw "Missing metadata.json: $($config.AzureMeta)"
        }
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
        $az = Get-Command az -ErrorAction SilentlyContinue
        if ($az) {
            $acct = az account show 2>$null | ConvertFrom-Json
            if (-not $acct) {
                Write-Host 'Run: az login' -ForegroundColor Yellow
                if (-not $CheckOnly) { az login }
            } else {
                Write-Host "Azure signed in as: $($acct.user.name)" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($CheckOnly) { exit 1 }
    exit 1
}

$releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $releaseDir 'evolve.exe'))) {
    Write-Host 'Windows release build not found. Run: scripts\build.ps1 windows' -ForegroundColor Yellow
    if ($CheckOnly) { exit 0 }
    exit 1
}

if ($CheckOnly) {
    & "$PSScriptRoot\verify_windows_signatures.ps1" -ReleaseDir $releaseDir
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host 'Signing release binaries...' -ForegroundColor Cyan
Sign-WindowsPeBinaries -Directory $releaseDir -Root $Root
Write-Host ''
& "$PSScriptRoot\verify_windows_signatures.ps1" -ReleaseDir $releaseDir
exit $LASTEXITCODE