# Verify the public PERC seed node matches the v3.1.1 wallet API contract.
param(
    [string]$SeedUrl = 'https://evolve-perc-internet.onrender.com',
    [int]$ExpectedGenesisRevision = 2,
    [string]$ChainId = 'evolve-chronoflux-principia-chain-1'
)

$ErrorActionPreference = 'Stop'
$base = $SeedUrl.TrimEnd('/')

function Get-SeedJson($Path) {
    $uri = "$base$Path"
    $r = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 12
    return $r
}

Write-Host "Checking seed compatibility: $base" -ForegroundColor Cyan
$failures = @()

try {
    $health = Get-SeedJson '/health'
    if (-not $health.ok) { $failures += 'health.ok is false' }
    if ($health.service -ne 'perc-internet-node') { $failures += "unexpected service: $($health.service)" }
    if (-not $health.ledgerReady) { $failures += 'ledger not ready' }
    Write-Host "  health: ok=$($health.ok) height=$($health.blockHeight) peersOnline=$($health.peersOnline)" -ForegroundColor Green
} catch {
    $failures += "health: $_"
}

try {
    $status = Get-SeedJson '/perc/status'
    if ($status.evolutionaryChainId -ne $ChainId) {
        $failures += "chain id mismatch: $($status.evolutionaryChainId)"
    }
    if ([int]$status.networkGenesisRevision -ne $ExpectedGenesisRevision) {
        $failures += "genesis revision $($status.networkGenesisRevision) != $ExpectedGenesisRevision"
    }
    Write-Host "  status: genesis=$($status.networkGenesisRevision) chain=$($status.evolutionaryChainId)" -ForegroundColor Green
} catch {
    $failures += "status: $_"
}

try {
    $ledger = Get-SeedJson '/perc/ledger'
    if ($ledger.networkGenesisRevision -ne $ExpectedGenesisRevision) {
        $failures += 'ledger genesis revision mismatch'
    }
    if (-not $ledger.PSObject.Properties['pendingInboundTransfers']) {
        $failures += 'ledger missing pendingInboundTransfers'
    }
    Write-Host "  ledger: blocks=$($ledger.blocks.Count) pending=$($ledger.pendingInboundTransfers.Count)" -ForegroundColor Green
} catch {
    $failures += "ledger: $_"
}

try {
    $online = Get-SeedJson '/perc/rendezvous/online?username=evolve_seed_node'
    if (-not $online.online) { $failures += 'seed peer not online' }
    Write-Host "  online API: seed online=$($online.online)" -ForegroundColor Green
} catch {
    $failures += "online endpoint missing or failed (wallet v3.1.1 requires GET /perc/rendezvous/online): $_"
}

try {
    $probe = 'percpriv1compatprobe00000000000000000001'
    $post = Invoke-RestMethod -Uri "$base/perc/rendezvous/address" -Method POST `
        -ContentType 'application/json' -Body (@{ address = $probe } | ConvertTo-Json) -TimeoutSec 12
    if (-not $post.ok) { $failures += 'POST /perc/rendezvous/address (address-only) failed' }
    $off = Get-SeedJson "/perc/rendezvous/online?address=$probe"
    if ($off.online) { $failures += 'address-only publish incorrectly marked online' }
    Write-Host '  address-only publish: ok' -ForegroundColor Green
} catch {
    $failures += "address endpoint: $_"
}

try {
    $peers = Invoke-RestMethod -Uri "$base/perc/rendezvous/peers?chainId=$([uri]::EscapeDataString($ChainId))" -TimeoutSec 12
    if ($peers.Count -lt 1) { $failures += 'no peers registered' }
    if (-not $peers[0].updatedAt) { $failures += 'peer missing updatedAt heartbeat' }
    Write-Host "  peers: $($peers.Count) with heartbeat" -ForegroundColor Green
} catch {
    $failures += "peers: $_"
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'SEED COMPATIBILITY: FAILED' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host ''
Write-Host 'SEED COMPATIBILITY: OK (v3.1.1 wallet API)' -ForegroundColor Green
exit 0