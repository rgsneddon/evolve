# Open Evolve Grok proxy in a clean, dedicated PowerShell window.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $PSScriptRoot 'start_grok_proxy.ps1'
. "$PSScriptRoot\lib\grok_env.ps1"

$port = if ($env:GROK_PROXY_PORT) { [int]$env:GROK_PROXY_PORT } else { 8787 }
Stop-GrokProxy -Port $port

Start-Process powershell.exe -ArgumentList @(
    '-NoLogo',
    '-NoExit',
    '-ExecutionPolicy', 'Bypass',
    '-File', $script
) -WorkingDirectory $Root

Write-Host "Grok proxy opening in a new window (port $port)." -ForegroundColor Green