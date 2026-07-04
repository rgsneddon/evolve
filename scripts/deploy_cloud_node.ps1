# Configure Evolve after deploying the Perccent internet node (Render, Fly.io, or VPS).
param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceUrl,
    [string]$RepoRoot = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = if ($RepoRoot) { $RepoRoot } else { Split-Path $PSScriptRoot -Parent }
$ConfigPath = Join-Path $Root 'assets\config\perc_network.json'

function Test-InternetNode {
    param([string]$BaseUrl)
    $base = $BaseUrl.Trim().TrimEnd('/')
    $checks = @(
        "$base/health",
        "$base/perc/rendezvous/peers?chainId=evolve-chronoflux-principia-chain-1",
        "$base/perc/status"
    )
    foreach ($uri in $checks) {
        try {
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 90
            if ($response.StatusCode -ne 200) {
                Write-Host "FAIL ($($response.StatusCode)): $uri" -ForegroundColor Red
                return $false
            }
            Write-Host "OK: $uri" -ForegroundColor Green
        } catch {
            Write-Host "FAIL: $uri - $_" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

function Set-PercNetworkConfig {
    param([string]$Url)
    $json = @{
        rendezvousUrl           = $Url.Trim().TrimEnd('/')
        publicEndpointOverride  = ''
        publicIpLookupUrls      = @(
            'https://api.ipify.org',
            'https://ifconfig.me/ip'
        )
    }
    $content = ($json | ConvertTo-Json -Depth 4)
    if ($DryRun) {
        Write-Host "[dry-run] Would write $ConfigPath" -ForegroundColor Yellow
        Write-Host $content
        return
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($ConfigPath, $content + "`n", $utf8NoBom)
    Write-Host "Updated $ConfigPath" -ForegroundColor Green
    Write-Host "  rendezvousUrl: $($json.rendezvousUrl)"
}

Write-Host ''
Write-Host 'Perccent cloud internet node setup' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-InternetNode -BaseUrl $ServiceUrl)) {
    throw "Internet node not healthy: $ServiceUrl"
}

Set-PercNetworkConfig -Url $ServiceUrl

Write-Host ''
Write-Host 'Configured. Rebuild/publish Evolve so assets/config/perc_network.json is bundled.' -ForegroundColor Green
Write-Host ''
Write-Host 'Free Render plan: service sleeps after ~15 min idle. First request may take 30-90s.' -ForegroundColor Yellow
Write-Host 'Optional keep-warm: scripts\setup_render_free.ps1 -ServiceUrl URL -KeepWarm' -ForegroundColor Yellow
Write-Host 'Treasury still runs in an Evolve wallet session (not on this cloud node).' -ForegroundColor Yellow