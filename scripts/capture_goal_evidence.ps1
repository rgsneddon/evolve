param(
  [string]$ScratchDir = "C:\Users\rgsne\AppData\Local\Temp\grok-goal-5ac23ba4e30f\implementer",
  [string]$BaseRef = "7c1d261"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Utf8NoBom([string]$Path, [string[]]$Lines) {
  [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function Append-Utf8NoBom([string]$Path, [string[]]$Lines) {
  $existing = @()
  if (Test-Path $Path) { $existing = [System.IO.File]::ReadAllLines($Path) }
  Write-Utf8NoBom $Path ($existing + $Lines)
}

function Invoke-Step($label, [scriptblock]$Command) {
  $stepLog = Join-Path $ScratchDir (($label -replace '[^a-zA-Z0-9]', '_') + ".log")
  & $Command *>&1 | ForEach-Object { $_.ToString() } | Set-Content -Path $stepLog -Encoding utf8
  $exit = $LASTEXITCODE
  Append-Utf8NoBom $testLog @("`n--- $label ---") + [System.IO.File]::ReadAllLines($stepLog)
  if ($exit -ne 0) { throw "$label failed with exit $exit" }
}

$testLog = Join-Path $ScratchDir "test_results.log"
$changedLog = Join-Path $ScratchDir "CHANGED_FILES.log"
$patchDelta = Join-Path $ScratchDir "PATCH_DELTA.diff"
$fullPatch = Join-Path $ScratchDir "evolve_app_full.patch"
$launchScript = Join-Path $ScratchDir "launch_network_probe.js"

Write-Utf8NoBom $testLog @(
  "=== GOAL EVIDENCE $(Get-Date -Format o) ==="
  "repo=$RepoRoot"
  "base_ref=$BaseRef"
)

Invoke-Step "STEP 1 transfer gating" {
  flutter test test/perc_wallet_transfer_delay_test.dart test/perc_online_offline_delivery_test.dart test/perc_send_settlement_test.dart test/perc_cross_device_send_test.dart test/perc_relay_golden_path_test.dart --reporter expanded
}

Invoke-Step "STEP 2 treasury staking planner" {
  flutter test test/perc_treasury_lock_test.dart test/perc_staking_test.dart test/treasury_scenario_settlement_test.dart test/inbound_transfer_settlement_test.dart --reporter expanded
}

Invoke-Step "STEP 3 node treasury" {
  node --test perc_chain/src/treasury_merge.test.js perc_chain/src/treasury_api.test.js
}

if (Test-Path $launchScript) {
  Invoke-Step "STEP 4 launch probe" { node $launchScript }
} else {
  Append-Utf8NoBom $testLog "`n--- STEP 4 launch probe SKIPPED (no launch_network_probe.js) ---"
}

$changedLines = @(
  "=== CHANGED FILES (evolve_app git diff $BaseRef..HEAD) ==="
  "repository=$RepoRoot"
  "note=Source repo is evolve_app; harness workspace C:\Users\rgsne tracks .grok/ only; mirror copied to goal/evolve_app_CHANGED_FILES.log"
)
$changedLines += git log --oneline "$BaseRef..HEAD"
$changedLines += ""
$changedLines += git diff --stat "$BaseRef..HEAD"
$changedLines += ""
$changedLines += git diff --name-only "$BaseRef..HEAD" | ForEach-Object { "evolve_app/$_" }
Write-Utf8NoBom $changedLog $changedLines

$focusedDiff = git diff "$BaseRef..HEAD" -- `
  lib/perc/perc_chain_constants.dart `
  lib/perc/services/inbound_transfer_settlement.dart `
  lib/perc/services/inbound_transfer_delivery.dart `
  lib/perc/services/treasury_scenario_settlement.dart `
  lib/perc/services/perc_ledger.dart `
  lib/perc/services/perc_settlement_witness.dart `
  lib/perc/providers/perc_wallet_provider.dart `
  lib/perc/models/perc_pending_inbound_transfer.dart `
  scripts/sync_inbound_revert_l10n.py `
  scripts/capture_goal_evidence.ps1 `
  test/inbound_transfer_settlement_test.dart `
  test/treasury_scenario_settlement_test.dart `
  test/perc_wallet_transfer_delay_test.dart `
  test/perc_cross_device_initiation_test.dart `
  test/perc_settlement_propagation_test.dart
Write-Utf8NoBom $patchDelta ($focusedDiff -split "`n")

$fullDiff = git diff "$BaseRef..HEAD"
Write-Utf8NoBom $fullPatch ($fullDiff -split "`n")

$manifestPaths = git diff --name-only "$BaseRef..HEAD" | ForEach-Object {
  @{ path = "evolve_app/$_"; status = "modified" }
}
$manifest = @{
  exported_utc = (Get-Date).ToUniversalTime().ToString("o")
  release = (Get-Content version.json -Raw | ConvertFrom-Json).version
  build = (Get-Content version.json -Raw | ConvertFrom-Json).build_number
  repo = $RepoRoot
  git_base = $BaseRef
  git_head = (git rev-parse HEAD).Trim()
  patch_file = "goal/evolve_app_instant_settlement.patch"
  deliverables = @($manifestPaths)
  scratch_evidence = @{
    test_results = "implementer/test_results.log"
    changed_files = "implementer/CHANGED_FILES.log"
    patch_delta = "implementer/PATCH_DELTA.diff"
    full_patch = "implementer/evolve_app_full.patch"
  }
}
$manifestJson = $manifest | ConvertTo-Json -Depth 6

$goalDirs = @(
  "C:\Users\rgsne\.grok\sessions\C%3A%5CUsers%5Crgsne%019eb3e3-4ce2-75b1-92c6-c955f37d2079\goal",
  "C:\Users\rgsne\.grok\sessions\C%3A%5CUsers%5Crgsne\019eb3e3-4ce2-75b1-92c6-c955f37d2079\goal",
  "C:\Users\rgsne\.grok\sessions\C%3A%5CUsers%5Crgsne%5C019eb3e3-4ce2-75b1-92c6-c955f37d2079\goal"
)

foreach ($goalDir in $goalDirs) {
  if (-not (Test-Path $goalDir)) { continue }
  Write-Utf8NoBom (Join-Path $goalDir "evolve_app_CHANGED_FILES.log") $changedLines
  Write-Utf8NoBom (Join-Path $goalDir "evolve_app_instant_settlement.patch") ($fullDiff -split "`n")
  Write-Utf8NoBom (Join-Path $goalDir "deliverables_manifest.json") ($manifestJson -split "`n")
}

Write-Host "Evidence written to $ScratchDir and mirrored to goal session dirs"