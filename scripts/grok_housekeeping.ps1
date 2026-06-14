# Grok housekeeping: stop stale processes, clear temp files, reset config, restart proxy.
param(
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\grok_env.ps1"

Clear-Host
Write-Host '=== Evolve Grok housekeeping ===' -ForegroundColor Cyan

foreach ($port in 8787, 8080, 8081) {
    Stop-GrokProxy -Port $port
    Write-Host "Cleared port $port" -ForegroundColor DarkGray
}

$tempServe = Join-Path $env:TEMP 'evolve_local_serve'
$legacyServe = Join-Path (Split-Path $Root -Parent) 'evolve_local_serve'
foreach ($dir in @($tempServe, $legacyServe)) {
    if (Test-Path $dir) {
        Remove-Item $dir -Recurse -Force
        Write-Host "Removed stale serve dir: $dir" -ForegroundColor DarkGray
    }
}

foreach ($crash in @('crash_stdout.txt', 'crash_stderr.txt')) {
    $path = Join-Path $Root $crash
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "Removed $crash" -ForegroundColor DarkGray
    }
}

& "$PSScriptRoot\write_grok_proxy_config.ps1" -ProxyUrl ''
Write-Host 'Reset assets/config/grok_proxy.json' -ForegroundColor DarkGray

if (-not $NoRestart) {
    & "$PSScriptRoot\start_grok_proxy_window.ps1"
    $deadline = (Get-Date).AddSeconds(12)
    do {
        Start-Sleep -Milliseconds 400
        if (Test-GrokProxyHealth) { break }
    } while ((Get-Date) -lt $deadline)

    if (Test-GrokProxyHealth) {
        Write-Host ''
        Write-Host 'Grok proxy ready: http://127.0.0.1:8787' -ForegroundColor Green
    } else {
        Write-Host ''
        Write-Host 'Grok proxy did not respond — check the Evolve Grok Proxy window.' -ForegroundColor Yellow
    }
} else {
    Write-Host ''
    Write-Host 'Housekeeping complete (proxy not restarted).' -ForegroundColor Green
}