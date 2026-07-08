# Deterministic security verification — sequential test run + grep gate.
$ErrorActionPreference = "Stop"
$Scratch = $env:SCRATCH
if (-not $Scratch) {
    $Scratch = Join-Path $env:TEMP "grok-goal-9099a7f2fd98\implementer"
}
New-Item -ItemType Directory -Force -Path $Scratch | Out-Null

$Log = Join-Path $Scratch "test_results.log"
$Changed = Join-Path $Scratch "CHANGED_FILES.log"
$Delta = Join-Path $Scratch "PATCH_DELTA.diff"

$TestFiles = @(
    "test/perc_send_settlement_test.dart",
    "test/perc_cross_device_send_test.dart",
    "test/perc_relay_golden_path_test.dart",
    "test/perc_settlement_propagation_test.dart",
    "test/inbound_transfer_settlement_test.dart",
    "test/perc_wallet_transfer_delay_test.dart",
    "test/perc_switch_commitment_test.dart",
    "test/perc_wallet_backup_test.dart",
    "test/perc_seed_recovery_test.dart",
    "test/perc_double_spend_guard_test.dart",
    "test/security_shell_navigation_test.dart",
    "test/security_backup_roundtrip_test.dart",
    "test/security_recovery_service_test.dart",
    "test/security_screen_backup_test.dart",
    "test/perc_seed_recovery_blank_device_test.dart"
)

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    flutter test @TestFiles --concurrency=1 --reporter expanded 2>&1 | Tee-Object -FilePath $Log
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter test failed with exit code $LASTEXITCODE"
    }

    $RequiredPatterns = @(
        "recovers full ledger from seed via injected SeedEnvelopeFetcher on blank ledger",
        "throws offline error when fetcher returns null and network unavailable",
        "Security tab export invokes save/download port with encrypted bytes",
        "provider recoverFromSeedPhrase fetches envelope via rendezvous override",
        "Security tab export button captures encrypted backup bytes",
        "Security tab restore button round-trips backup on blank store",
        "All tests passed"
    )

    $logText = Get-Content $Log -Raw
    foreach ($pattern in $RequiredPatterns) {
        if ($logText -notmatch [regex]::Escape($pattern)) {
            Write-Error "Missing required log line: $pattern"
        }
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    git diff --stat | Out-File -FilePath $Changed -Encoding utf8
    git diff lib/perc/services/security_recovery_service.dart lib/perc/screens/security_screen.dart lib/perc/providers/perc_wallet_provider.dart lib/perc/services/perc_network_rendezvous.dart test/security_recovery_service_test.dart test/security_screen_backup_test.dart tool/verify_security.ps1 | Out-File -FilePath $Delta -Encoding utf8
    $ErrorActionPreference = $prevEap

    Write-Host "verify_security.ps1: all gates passed"
}
finally {
    Pop-Location
}