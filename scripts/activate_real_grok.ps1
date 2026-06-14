# Switch Grok proxy from mock to real X OAuth.
# 1. Edit grok_proxy.local.env and set X_CLIENT_ID (required).
# 2. Run: powershell -ExecutionPolicy Bypass -File .\scripts\activate_real_grok.ps1

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
. "$PSScriptRoot\lib\grok_env.ps1"

$envFile = Join-Path $Root 'grok_proxy.local.env'
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $Root 'grok_proxy.local.env.example') $envFile
    Write-Host 'Created grok_proxy.local.env - add your X_CLIENT_ID, then re-run.' -ForegroundColor Yellow
    notepad $envFile
    exit 1
}

Remove-Item Env:GROK_PROXY_MOCK -ErrorAction SilentlyContinue
Import-GrokLocalEnv -Root $Root | Out-Null

if (-not $env:X_CLIENT_ID -or $env:X_CLIENT_ID -match 'your_x_oauth') {
    Write-Host 'X_CLIENT_ID missing in grok_proxy.local.env' -ForegroundColor Red
    Write-Host ''
    Write-Host 'X Developer setup (fixes "Something went wrong"):' -ForegroundColor Cyan
    Write-Host '  1. https://console.x.com/ - your app - User authentication - OAuth 2.0 ON'
    Write-Host '  2. App type: Native App (desktop) or Web App'
    Write-Host '  3. Callback URL EXACTLY: http://127.0.0.1:8787/auth/callback (not localhost)'
    Write-Host '  4. Scopes: tweet.read, users.read, offline.access'
    Write-Host '  5. Copy Client ID into grok_proxy.local.env (and next to evolve.exe on Windows)'
    Write-Host ''
    notepad $envFile
    exit 1
}

$port = if ($env:GROK_PROXY_PORT) { [int]$env:GROK_PROXY_PORT } else { 8787 }
Stop-GrokProxy -Port $port
Start-Sleep -Seconds 1

Set-GrokDartPath | Out-Null
$proxy = Start-Process -FilePath 'dart' -ArgumentList 'run', 'tool/grok_proxy.dart' `
    -WorkingDirectory $Root -PassThru -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds(12)
do {
    Start-Sleep -Milliseconds 400
    if (Test-GrokProxyHealth -Port $port) { break }
} while ((Get-Date) -lt $deadline)

if (-not (Test-GrokProxyHealth -Port $port)) {
    Write-Host 'Proxy failed to start.' -ForegroundColor Red
    exit 1
}

$login = Invoke-RestMethod -Uri "http://127.0.0.1:$port/auth/login" -TimeoutSec 5
$url = $login.authorizeUrl
if ($url -match 'twitter\.com|x\.com') {
    Write-Host 'Real mode active - X OAuth URL ready.' -ForegroundColor Green
    Write-Host "  $url"
    Write-Host ''
    Write-Host 'Next: hard-refresh http://127.0.0.1:8080 and tap SIGN IN WITH X' -ForegroundColor Cyan
} else {
    Write-Host "Still in mock mode (authorizeUrl: $url)" -ForegroundColor Yellow
    Write-Host 'Check X_CLIENT_ID in grok_proxy.local.env and restart.' -ForegroundColor Yellow
}

Write-Host "Proxy PID: $($proxy.Id) on port $port" -ForegroundColor DarkGray