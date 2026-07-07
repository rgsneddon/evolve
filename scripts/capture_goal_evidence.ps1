param(
  [string]$ScratchDir = "C:\Users\rgsne\AppData\Local\Temp\grok-goal-5ac23ba4e30f\implementer",
  [string]$BaseRef = "7c1d261"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

$testLog = Join-Path $ScratchDir "test_results.log"
$changedLog = Join-Path $ScratchDir "CHANGED_FILES.log"
$patchDelta = Join-Path $ScratchDir "PATCH_DELTA.diff"
$launchScript = Join-Path $ScratchDir "launch_network_probe.js"

"=== GOAL EVIDENCE $(Get-Date -Format o) ===" | Out-File -Encoding utf8 $testLog
"repo=$RepoRoot" | Add-Content $testLog

function Invoke-Step($label, $command) {
  "`n--- $label ---" | Add-Content $testLog
  $stepLog = Join-Path $ScratchDir (($label -replace '[^a-zA-Z0-9]', '_') + ".log")
  Invoke-Expression $command 2>&1 | Tee-Object -FilePath $stepLog | Add-Content $testLog
  if ($LASTEXITCODE -ne 0) { throw "$label failed with exit $LASTEXITCODE" }
}

Invoke-Step "STEP 1 transfer gating" `
  "flutter test test/perc_wallet_transfer_delay_test.dart test/perc_online_offline_delivery_test.dart test/perc_send_settlement_test.dart test/perc_cross_device_send_test.dart test/perc_relay_golden_path_test.dart --reporter expanded"

Invoke-Step "STEP 2 treasury staking planner" `
  "flutter test test/perc_treasury_lock_test.dart test/perc_staking_test.dart test/treasury_scenario_settlement_test.dart test/inbound_transfer_settlement_test.dart --reporter expanded"

Invoke-Step "STEP 3 node treasury" `
  "node --test perc_chain/src/treasury_merge.test.js perc_chain/src/treasury_api.test.js"

if (Test-Path $launchScript) {
  Invoke-Step "STEP 4 launch probe" "node `"$launchScript`""
} else {
  "`n--- STEP 4 launch probe SKIPPED (no launch_network_probe.js) ---" | Add-Content $testLog
}

"=== CHANGED FILES (git diff $BaseRef..HEAD) ===" | Out-File -Encoding utf8 $changedLog
"repository=$RepoRoot" | Add-Content $changedLog
git log --oneline "$BaseRef..HEAD" | Add-Content $changedLog
"" | Add-Content $changedLog
git diff --stat "$BaseRef..HEAD" | Add-Content $changedLog
"" | Add-Content $changedLog
git diff --name-only "$BaseRef..HEAD" | ForEach-Object { Join-Path $RepoRoot $_ } | Add-Content $changedLog

git diff "$BaseRef..HEAD" -- `
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
  test/perc_settlement_propagation_test.dart | Out-File -Encoding utf8 $patchDelta

Write-Host "Evidence written to $ScratchDir"