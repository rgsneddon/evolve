# Local web preview with live Grok proxy.
# 1. Copy grok_proxy.local.env.example → grok_proxy.local.env and add keys (optional).
# 2. Run this script — proxy window + web at http://127.0.0.1:8081/evolve/
param(
    [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"
. "$PSScriptRoot\lib\grok_env.ps1"

if (-not (Import-GrokLocalEnv -Root $Root)) {
    Write-Host 'No grok_proxy.local.env — proxy runs in mock mode.' -ForegroundColor Yellow
}

$proxyPort = if ($env:GROK_PROXY_PORT) { [int]$env:GROK_PROXY_PORT } else { 8787 }
& "$PSScriptRoot\start_grok_proxy_window.ps1"

$deadline = (Get-Date).AddSeconds(15)
do {
    Start-Sleep -Milliseconds 400
    if (Test-GrokProxyHealth -Port $proxyPort) { break }
} while ((Get-Date) -lt $deadline)

$flutter = (Set-BuildEnvironment).FlutterExe
Set-Location $Root
$env:GROK_PROXY_URL = "http://127.0.0.1:$proxyPort"
& "$PSScriptRoot\write_grok_proxy_config.ps1" -ProxyUrl $env:GROK_PROXY_URL

Write-Host 'Building web with Grok proxy URL...' -ForegroundColor Cyan
& $flutter build web --release --base-href /evolve/ --dart-define=GROK_PROXY_URL=$env:GROK_PROXY_URL

$serveRoot = Join-Path $env:TEMP 'evolve_local_serve'
$appRoot = Join-Path $serveRoot 'evolve'
if (Test-Path $serveRoot) { Remove-Item $serveRoot -Recurse -Force }
New-Item -ItemType Directory -Path $appRoot -Force | Out-Null
Copy-Item -Path (Join-Path $Root 'build\web\*') -Destination $appRoot -Recurse -Force

Stop-GrokProxy -Port $Port
Set-Location $serveRoot
Write-Host ''
Write-Host "Open: http://127.0.0.1:$Port/evolve/" -ForegroundColor Green
Start-Process "http://127.0.0.1:$Port/evolve/"
python -m http.server $Port