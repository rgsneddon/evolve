# Build Evolve for one platform: web | windows | android | apk
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('web', 'windows', 'android', 'apk')]
    [string]$Platform,

    [switch]$DebugBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"

$info = Set-BuildEnvironment
$flutter = $info.FlutterExe
$mode = if ($DebugBuild) { '--debug' } else { '--release' }

Set-Location $Root

switch ($Platform) {
    'web' {
        & $flutter build web $mode
        Write-Host ''
        Write-Host 'Output: build\web' -ForegroundColor Green
        Write-Host 'Serve:  flutter run -d web-server --web-port 8080 --release' -ForegroundColor Green
    }
    'windows' {
        & $flutter build windows $mode
        $envSrc = Join-Path $Root 'grok_proxy.local.env'
        $envDst = Join-Path $Root 'build\windows\x64\runner\Release\grok_proxy.local.env'
        if (Test-Path $envSrc) {
            Copy-Item $envSrc $envDst -Force
            Write-Host 'Copied grok_proxy.local.env beside evolve.exe' -ForegroundColor Cyan
        } else {
            Write-Host 'No grok_proxy.local.env — Windows Grok will use mock X sign-in.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host 'Output: build\windows\x64\runner\Release\evolve.exe' -ForegroundColor Green
    }
    { $_ -in 'android', 'apk' } {
        if (-not $info.JavaHome) {
            throw 'JDK required for Android builds. Run scripts\setup_build_tooling.ps1 first.'
        }
        & $flutter build apk $mode
        Write-Host ''
        Write-Host 'Output: build\app\outputs\flutter-apk\app-release.apk' -ForegroundColor Green
    }
}