# Build a versioned Windows setup.exe from the Flutter Release folder (Inno Setup).
param(
    [string]$Version = '',
    [string]$Build = '',
    [switch]$SkipWindowsBuild,
    [switch]$SkipCodeSign
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"
. "$PSScriptRoot\lib\package_checksum.ps1"
. "$PSScriptRoot\lib\code_sign.ps1"

Set-Location $Root

if (-not $Version -or -not $Build) {
    $pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
    if ($pubspec -match 'version:\s*([0-9.]+)\+(\d+)') {
        if (-not $Version) { $Version = $Matches[1] }
        if (-not $Build) { $Build = $Matches[2] }
    } else {
        throw 'Could not read version from pubspec.yaml'
    }
}

$releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
$exePath = Join-Path $releaseDir 'evolve.exe'

if (-not $SkipWindowsBuild) {
    & "$PSScriptRoot\build.ps1" -Platform windows
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Test-Path $exePath)) {
    throw "Missing Windows release build: $exePath"
}

Assert-WindowsSigningReadiness -Root $Root -SkipCodeSign:$SkipCodeSign

Sign-WindowsPeBinaries -Directory $releaseDir -Root $Root -SkipCodeSign:$SkipCodeSign

function Find-InnoSetupCompiler {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

$iscc = Find-InnoSetupCompiler
if (-not $iscc) {
    Write-Host 'Installing Inno Setup 6 (winget)...' -ForegroundColor Cyan
    winget install -e --id JRSoftware.InnoSetup --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw 'Failed to install Inno Setup. Install manually from https://jrsoftware.org/isinfo.php' }
    $iscc = Find-InnoSetupCompiler
    if (-not $iscc) { throw 'Inno Setup installed but ISCC.exe not found. Re-open shell and retry.' }
}

$outDir = Join-Path $Root "build\installer\windows"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$iss = Join-Path $Root 'installer\windows\evolve.iss'
Write-Host "Building installer v$Version (build $Build)..." -ForegroundColor Cyan
& $iscc $iss "/DEvolveVersion=$Version" "/DEvolveBuild=$Build"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$setupName = "evolve-v$Version-windows-x64-setup.exe"
$setupPath = Join-Path $outDir $setupName
if (-not (Test-Path $setupPath)) {
    throw "Installer not produced: $setupPath"
}

if (-not $SkipCodeSign) {
    $signTool = Find-SignTool
    $signConfig = Get-CodeSignConfig -Root $Root
    Sign-AuthenticodeFile -FilePath $setupPath -Config $signConfig -SignTool $signTool | Out-Null
}

if (-not $SkipCodeSign) {
    Write-Host ''
    Write-Host '=== Post-sign Authenticode verification ===' -ForegroundColor Cyan
    Test-WindowsPeBinariesSigned -Directory $releaseDir | Out-Null
    $signTool = Find-SignTool
    $setupVerify = Test-AuthenticodeTrustedSignature -FilePath $setupPath -SignTool $signTool
    if (-not $setupVerify.Valid) {
        throw "Installer signature verification failed: $($setupVerify.Message)"
    }
    Write-Host "OK  $setupPath" -ForegroundColor Green
}

$versionedDir = Join-Path $Root "build\downloads\v$Version"
New-Item -ItemType Directory -Path $versionedDir -Force | Out-Null
$publishedName = $setupName
$publishedPath = Join-Path $versionedDir $publishedName
Copy-Item $setupPath $publishedPath -Force

$signed = Write-PackageChecksumSidecar `
    -PackagePath $publishedPath `
    -Version $Version `
    -Build $Build `
    -Platform 'windows' `
    -Url "https://rgsneddon.github.io/evolve/downloads/v$Version/$publishedName"

Write-Host ''
Write-Host 'Installer ready:' -ForegroundColor Green
Write-Host "  $publishedPath"
Write-Host "  $($signed.Sha256Path)"
Write-Host "  $($signed.Sha512Path)"
Write-Host ''
Write-Host 'Secure versioned URL (after gh-pages deploy):' -ForegroundColor Cyan
Write-Host "  https://rgsneddon.github.io/evolve/downloads/v$Version/$publishedName"
Write-Host "SHA-256: $($signed.Sha256)" -ForegroundColor Cyan
Write-Host "SHA-512: $($signed.Sha512)" -ForegroundColor Cyan