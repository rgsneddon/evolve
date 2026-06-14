# Installs Android command-line SDK for Flutter builds (no full Android Studio required).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\env.ps1"

$SdkRoot = Get-AndroidSdkRoot
$CmdlineLatest = Join-Path $SdkRoot 'cmdline-tools\latest'
$ZipPath = Join-Path $env:TEMP 'android-cmdline-tools.zip'
$Url = 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'

Write-Host "Android SDK root: $SdkRoot"
New-Item -ItemType Directory -Force -Path $CmdlineLatest | Out-Null

if (-not (Test-Path (Join-Path $CmdlineLatest 'bin\sdkmanager.bat'))) {
    Write-Host 'Downloading Android command-line tools...'
    curl.exe -L --retry 3 -o $ZipPath $Url
    $ExtractDir = Join-Path $env:TEMP 'android-cmdline-tools-extract'
    if (Test-Path $ExtractDir) { Remove-Item $ExtractDir -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force
    if (Test-Path $CmdlineLatest) { Remove-Item $CmdlineLatest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path $CmdlineLatest) | Out-Null
    Move-Item (Join-Path $ExtractDir 'cmdline-tools') $CmdlineLatest
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
}

$envInfo = Set-BuildEnvironment
$jdkHome = $envInfo.JavaHome
if (-not $jdkHome) {
    Write-Host 'JDK not found yet; install OpenJDK 17 then re-run this script.' -ForegroundColor Yellow
}

$sdkmanager = Join-Path $CmdlineLatest 'bin\sdkmanager.bat'
Write-Host 'Installing SDK packages (platform-tools, platform 35, build-tools)...'
& $sdkmanager --sdk_root=$SdkRoot 'platform-tools' 'platforms;android-35' 'build-tools;35.0.0' 'build-tools;34.0.0' 'ndk;27.0.12077973' 'cmake;3.22.1' 'cmdline-tools;latest'

Write-Host 'Accepting Android licenses...'
$yes = ('y' * 200) -join "`n"
$yes | & $sdkmanager --sdk_root=$SdkRoot --licenses

Set-BuildEnvironment -Persist | Out-Null
Write-Host 'Done. Restart terminal and run: .\scripts\doctor.ps1'