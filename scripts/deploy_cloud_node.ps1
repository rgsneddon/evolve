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
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 25
            if ($response.StatusCode -ne 200) {
                Write-Host "FAIL ($($response.StatusCode)): $uri" -ForegroundColor Red
                return $false
            }
            Write-Host "OK: $uri" -ForegroundColor Green
        } catch {
            Write-Host "FAIL: $uri — $_" -ForegroundColor Red
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
Write-Host @'
PLATFORM COMPARISON (same Docker image / perc_chain):

  Render FREE — easiest one-click deploy
    https://render.com/deploy?repo=https://github.com/rgsneddon/evolve
    Pros: zero setup, free HTTPS
    Cons: sleeps after ~15 min idle; cold starts; ledger resets on redeploy

  Render STARTER (~$7/mo) — recommended for production seed node
    Same blueprint, change plan to Starter in dashboard
    Pros: always on, no cold starts
    Cons: monthly cost

  Fly.io (~$0–3/mo) — cheapest true always-on
    cd perc_chain
    fly launch --no-deploy
    fly volumes create perc_data --size 1 --region lhr
    fly deploy
    Pros: min_machines_running=1 keeps it awake; persistent volume
    Cons: requires flyctl + card on file

  Hetzner CX22 (~€4/mo) — cheapest VPS
    docker build -t evolve-perc perc_chain
    docker run -d -p 9478:9478 -v perc-data:/var/data -e PERC_PUBLIC_ENDPOINT=http://YOUR_IP:9478 evolve-perc
    Pros: full control, always on, persistent disk
    Cons: you manage updates/firewall

The cloud service is BOTH rendezvous AND seed node (username evolve_seed_node).
It is NOT the treasury — treasury still runs inside an Evolve wallet session.
'@ -ForegroundColor Yellow