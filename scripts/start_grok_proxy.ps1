# Standalone Grok proxy (desktop app also auto-starts one on "Use").
# Mock:  GROK_PROXY_MOCK=1  |  Live: X_CLIENT_ID + XAI_API_KEY in grok_proxy.local.env

$ErrorActionPreference = 'Stop'
Clear-Host
$Host.UI.RawUI.WindowTitle = 'Evolve Grok Proxy'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
. "$PSScriptRoot\lib\grok_env.ps1"

Set-GrokDartPath | Out-Null

if (Import-GrokLocalEnv -Root $Root) {
    Write-Host "Loaded grok_proxy.local.env" -ForegroundColor Cyan
}

if ($env:X_CLIENT_ID -and $env:X_CLIENT_ID -notmatch 'your_x_oauth') {
    Remove-Item Env:GROK_PROXY_MOCK -ErrorAction SilentlyContinue
    Write-Host 'Real X OAuth mode (X_CLIENT_ID set).' -ForegroundColor Green
} elseif (-not $env:GROK_PROXY_MOCK) {
    Write-Host 'No X_CLIENT_ID — mock mode (dev Premium bypass).' -ForegroundColor Yellow
    $env:GROK_PROXY_MOCK = '1'
}

$port = if ($env:GROK_PROXY_PORT) { $env:GROK_PROXY_PORT } else { '8787' }
Write-Host "Evolve Grok proxy — http://127.0.0.1:$port" -ForegroundColor Cyan
Write-Host 'Close this window to stop the proxy.' -ForegroundColor DarkGray
Write-Host ''

dart run tool/grok_proxy.dart