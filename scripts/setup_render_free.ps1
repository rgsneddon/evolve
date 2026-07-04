# Render FREE (Hobby) — deploy evolve-perc-internet and wire Evolve config.
param(
    [string]$ServiceUrl = '',
    [switch]$KeepWarm,
    [int]$PingMinutes = 14
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$DeployUrl = 'https://render.com/deploy?repo=https://github.com/rgsneddon/evolve'
$ExpectedUrl = 'https://evolve-perc-internet.onrender.com'

Write-Host ''
Write-Host 'Render FREE (Hobby) — Perccent internet node' -ForegroundColor Cyan
Write-Host ''

if (-not $ServiceUrl) {
    Write-Host 'Step 1 — Deploy on Render (one-time, ~3 min)' -ForegroundColor Yellow
    Write-Host "  Open: $DeployUrl"
    Write-Host '  Sign in with GitHub, approve the blueprint, wait for green Live status.'
    Write-Host "  Default URL: $ExpectedUrl"
    Write-Host ''
    Start-Process $DeployUrl
    $ServiceUrl = Read-Host 'Step 2 — Paste your Render service URL (or press Enter for default)'
    if (-not $ServiceUrl) { $ServiceUrl = $ExpectedUrl }
}

Write-Host ''
Write-Host "Configuring Evolve for: $ServiceUrl" -ForegroundColor Cyan

# Free tier cold starts can take 30–90s on first request.
$ready = $false
for ($i = 1; $i -le 6; $i++) {
    Write-Host "Health check attempt $i/6 (cold start may take up to 90s)..." -ForegroundColor DarkGray
    try {
        & (Join-Path $PSScriptRoot 'deploy_cloud_node.ps1') -ServiceUrl $ServiceUrl
        $ready = $true
        break
    } catch {
        if ($i -lt 6) {
            Write-Host '  Service waking up — retrying in 20s...' -ForegroundColor Yellow
            Start-Sleep -Seconds 20
        } else {
            throw $_
        }
    }
}

if (-not $ready) { throw 'Render service not reachable.' }

Write-Host ''
Write-Host 'FREE PLAN NOTES:' -ForegroundColor Yellow
Write-Host '  - Service sleeps after ~15 min with no traffic (cold start on next wallet sync).'
Write-Host '  - Ledger re-syncs from online wallets after each wake — no paid disk on free tier.'
Write-Host '  - First request after sleep may take 30–90 seconds.'
Write-Host '  - Upgrade to Starter ($7/mo) in Render dashboard for true always-on.'
Write-Host ''

if ($KeepWarm) {
    Write-Host "Starting keep-warm pinger (every $PingMinutes min). Close window to stop." -ForegroundColor Cyan
    $uri = "$($ServiceUrl.Trim().TrimEnd('/'))/health"
    while ($true) {
        try {
            $r = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 90
            Write-Host "$(Get-Date -Format 'HH:mm:ss') ping OK ($($r.StatusCode))" -ForegroundColor Green
        } catch {
            Write-Host "$(Get-Date -Format 'HH:mm:ss') ping failed (may be cold starting)" -ForegroundColor DarkYellow
        }
        Start-Sleep -Seconds ($PingMinutes * 60)
    }
}

Write-Host 'Next: rebuild/publish Evolve so perc_network.json is bundled in the app.' -ForegroundColor Green