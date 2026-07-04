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
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $candidates = @(
        $(if ($nodeCmd) { $nodeCmd.Source } else { $null }),
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
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($ConfigPath, $content + "`n", $utf8NoBom)
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

RECOMMENDED — Render (free HTTPS; use Starter for always-on):
  1. Open https://render.com/deploy?repo=https://github.com/rgsneddon/evolve
  2. Sign in and approve the blueprint (creates evolve-perc-internet)
  3. Copy the service URL (e.g. https://evolve-perc-internet.onrender.com)
  4. Run:
       scripts\deploy_cloud_node.ps1 -ServiceUrl "https://YOUR-SERVICE.onrender.com"

INTERIM — Cloudflare quick tunnel (this PC must stay online):
  scripts\start_rendezvous_public.ps1 -UpdateConfig

Then rebuild/publish Evolve installers and web.

Optional — local dev only:
  scripts\deploy_rendezvous.ps1 -LocalOnly

Optional — fixed public IP / domain for wallet nodes:
  Edit assets\config\perc_network.json:
    "publicEndpointOverride": "http://YOUR_PUBLIC_IP:9477"
  Forward TCP 9477 on your router to the PC running Evolve.
'@ -ForegroundColor Yellow

exit 0