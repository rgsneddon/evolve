# Deploy Perccent internet rendezvous and update app network config.
param(
    [string]$RendezvousUrl = '',
    [string]$RepoRoot = '',
    [switch]$LocalOnly,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = if ($RepoRoot) { $RepoRoot } else { Split-Path $PSScriptRoot -Parent }
$PercChain = Join-Path $Root 'perc_chain'
$ConfigPath = Join-Path $Root 'assets\config\perc_network.json'

function Get-NodeExe {
    $candidates = @(
        (Get-Command node -ErrorAction SilentlyContinue)?.Source,
        'C:\Program Files\nodejs\node.exe',
        "$env:ProgramFiles\nodejs\node.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }
    if ($candidates) { return $candidates[0] }
    throw 'Node.js not found. Install from https://nodejs.org or run: winget install OpenJS.NodeJS.LTS'
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
    Set-Content -Path $ConfigPath -Value $content -Encoding UTF8
    Write-Host "Updated $ConfigPath" -ForegroundColor Green
    Write-Host "  rendezvousUrl: $($json.rendezvousUrl)"
}

function Test-Rendezvous {
    param([string]$BaseUrl)
    $uri = "$($BaseUrl.Trim().TrimEnd('/'))/perc/rendezvous/peers?chainId=evolve-chronoflux-principia-chain-1"
    try {
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 20
        if ($response.StatusCode -eq 200) {
            Write-Host "Rendezvous OK: $uri" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "Rendezvous check failed: $_" -ForegroundColor Red
    }
    return $false
}

Write-Host ''
Write-Host 'Perccent rendezvous deployment' -ForegroundColor Cyan
Write-Host ''

if ($LocalOnly) {
    $node = Get-NodeExe
    $port = 9478
    Write-Host "Starting local rendezvous on port $port ..." -ForegroundColor Cyan
    $env:PERC_RENDEZVOUS_PORT = "$port"
    Start-Process -FilePath $node -ArgumentList (Join-Path $PercChain 'src\rendezvous.js') -WorkingDirectory $PercChain -WindowStyle Minimized
    Start-Sleep -Seconds 2
    $localUrl = "http://127.0.0.1:$port"
    if (Test-Rendezvous -BaseUrl $localUrl) {
        Write-Host ''
        Write-Host 'Local rendezvous is running (LAN/dev only).' -ForegroundColor Yellow
        Write-Host "  $localUrl"
        Write-Host 'For internet wallets, deploy to Render (see below) or set publicEndpointOverride.'
    }
    exit 0
}

if ($RendezvousUrl) {
    if (-not (Test-Rendezvous -BaseUrl $RendezvousUrl)) {
        throw "Rendezvous URL not reachable: $RendezvousUrl"
    }
    Set-PercNetworkConfig -Url $RendezvousUrl
    Write-Host ''
    Write-Host 'Done. Rebuild Evolve so assets/config/perc_network.json is bundled.' -ForegroundColor Green
    exit 0
}

Write-Host @'
No rendezvous URL configured yet.

RECOMMENDED — Render (free public HTTPS host):
  1. Push this repo to GitHub (main branch).
  2. Open https://dashboard.render.com/select-repo?type=blueprint
  3. Connect github.com/rgsneddon/evolve
  4. Render reads perc_chain/render.yaml and creates evolve-perc-rendezvous
  5. After deploy, copy the service URL (e.g. https://evolve-perc-rendezvous.onrender.com)
  6. Run:
       scripts\deploy_rendezvous.ps1 -RendezvousUrl "https://YOUR-SERVICE.onrender.com"

Then rebuild/publish Evolve installers and web.

Optional — local dev only:
  scripts\deploy_rendezvous.ps1 -LocalOnly

Optional — fixed public IP / domain for wallet nodes:
  Edit assets\config\perc_network.json:
    "publicEndpointOverride": "http://YOUR_PUBLIC_IP:9477"
  Forward TCP 9477 on your router to the PC running Evolve.
'@ -ForegroundColor Yellow

exit 0