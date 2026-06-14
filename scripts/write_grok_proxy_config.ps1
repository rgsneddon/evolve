# Write assets/config/grok_proxy.json from GROK_PROXY_URL (build-time web config).
param(
    [string]$ProxyUrl = $env:GROK_PROXY_URL
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$outPath = Join-Path $Root 'assets\config\grok_proxy.json'
$url = if ($ProxyUrl) { $ProxyUrl.Trim().TrimEnd('/') } else { '' }

@{
    proxyUrl = $url
} | ConvertTo-Json | Set-Content -Path $outPath -Encoding UTF8

Write-Host "Grok proxy config: $outPath -> '$url'" -ForegroundColor Cyan