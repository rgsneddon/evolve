# Start Perccent rendezvous locally and expose it on the public internet via Cloudflare quick tunnel.
# For production, deploy to Render instead: https://render.com/deploy?repo=https://github.com/rgsneddon/evolve
param(
    [int]$Port = 9478,
    [switch]$UpdateConfig
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$PercChain = Join-Path $Root 'perc_chain'
$Node = 'C:\Program Files\nodejs\node.exe'
$Cloudflared = Join-Path $PercChain 'cloudflared.exe'
$Rendezvous = Join-Path $PercChain 'src\rendezvous.js'

if (-not (Test-Path $Node)) { throw "Node.js not found at $Node" }
if (-not (Test-Path $Rendezvous)) { throw "Rendezvous script not found: $Rendezvous" }

if (-not (Test-Path $Cloudflared)) {
    Write-Host 'Downloading cloudflared...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/download/2026.6.1/cloudflared-windows-amd64.exe' `
        -OutFile $Cloudflared -UseBasicParsing
}

$existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Starting rendezvous on port $Port ..." -ForegroundColor Cyan
    $env:PERC_RENDEZVOUS_PORT = "$Port"
    Start-Process -FilePath $Node -ArgumentList $Rendezvous -WorkingDirectory $PercChain -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

Write-Host 'Starting Cloudflare quick tunnel (public HTTPS)...' -ForegroundColor Cyan
$log = Join-Path $env:TEMP "perc-rendezvous-tunnel-$Port.log"
if (Test-Path $log) { Remove-Item $log -Force }
$cf = Start-Process -FilePath $Cloudflared -ArgumentList @('tunnel', '--url', "http://127.0.0.1:$Port") `
    -RedirectStandardOutput $log -RedirectStandardError $log -PassThru -WindowStyle Hidden

$publicUrl = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $log) {
        $match = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -AllMatches | Select-Object -First 1
        if ($match) {
            $publicUrl = $match.Matches[0].Value
            break
        }
    }
}

if (-not $publicUrl) {
    throw "Tunnel URL not found in $log (cloudflared pid $($cf.Id))"
}

Write-Host ''
Write-Host "Public rendezvous URL: $publicUrl" -ForegroundColor Green
Write-Host "Health: $publicUrl/health"
Write-Host "Peers:  $publicUrl/perc/rendezvous/peers?chainId=evolve-chronoflux-principia-chain-1"
Write-Host ''
Write-Host 'Keep this PC online. For permanent hosting use Render (see deploy_rendezvous.ps1).' -ForegroundColor Yellow

if ($UpdateConfig) {
    & (Join-Path $PSScriptRoot 'deploy_rendezvous.ps1') -RendezvousUrl $publicUrl
}