# Manual test checklist — Evolve, Perccent Wallet, and PERC chain

Run these after automated suites (`flutter test`, `perc_chain/npm test`, and **run security audit**) pass. Tick each item when you have observed the expected outcome on a real device or network.

**Automated baseline (run before manual QA):**

```powershell
# From C:\Users\rgsne
powershell -NoProfile -ExecutionPolicy Bypass -File run_security_audit.ps1
cd evolve_app; flutter test
cd evolve_app\perc_chain; npm test
cd ..\..\perccent_wallet; flutter test
cd perccent_wallet\perc_chain; npm test
```

---

## 1. PERC blockchain — ledger and chain tip

1. **Genesis and launch** — Open Evolve or Perccent Wallet on a fresh profile; confirm blockchain launches, genesis revision matches seed (`networkGenesisRevision=2`), and block height starts at expected pilot height.
2. **Chain tip parity** — On seed `/perc/status`, note `blockHeight` and tip hash; compare with wallet block list; heights and latest block label must agree.
3. **Scenario settlement** — Complete one percent-chance scenario in Evolve; confirm treasury debits, wallet credits, and a new block appears with correct scenario label.
4. **Manual transfer** — Send PERC between two wallets on the same seed; sender balance drops, recipient receives near-instantly, block shows Manual tx.
5. **Double-spend guard** — Attempt to replay the same signed transfer; wallet or seed must reject with insufficient balance or duplicate-tx error.

## 2. Settlement, relay, and cross-device delivery

6. **Relay golden path** — Send from Wallet A to offline Wallet B; confirm pending inbound on B, then settlement after B syncs; relay source index visible in block detail.
7. **Cross-device initiation** — Start send on phone, complete on desktop (or vice versa); initiation merge then settlement relay must not duplicate tx id.
8. **24-hour revert** — (Staging only) Leave inbound unsettled past revert window; PERC returns to sender per `perc_wallet_transfer_delay_test` policy.
9. **Settlement witness** — After receiver confirms, seed merge shows settled state; explorer/API `resolveRelayBlockView` returns transfer at canonical index.

## 3. Treasury, staking, and emission

10. **Treasury lock** — Confirm manual sends to `evolve_treasury` are rejected after launch; scenario rewards still debit treasury correctly.
11. **Staking payout** — Stake PERC, advance blocks or sync seed; staking reward block appears and treasury conservation holds (no supply inflation).
12. **Microblock / ward seal** — Observe microblock counter and ward bundling in wallet UI or debug logs; seal cycle matches 10,000 microblocks per ward in tests.

## 4. Seed sync, rendezvous, and network health

13. **Live seed health** — `GET https://evolve-perc-internet.onrender.com/health` returns `ok:true`, `ledgerReady:true`; `/perc/status` chain id is `evolve-chronoflux-principia-chain-1`.
14. **Rendezvous peers** — Wallet registers; `/perc/rendezvous/peers?chainId=...` lists at least the seed; peer heartbeats within 7 minutes show online.
15. **Seed wallet compat** — Run `npm run test:seed-compat` in `perc_chain/` when network is stable; live seed API must match wallet v3.1.1+ contract (or skip logs unreachable seed).
16. **Upstream merge** — With two seeds on same chain id, confirm upstream peer merge does not clobber taller canonical tip.

## 5. Wallet architecture — Evolve vs standalone Perccent

17. **Evolve integration boundary** — In Evolve, wallet tab shares ledger with scenarios; Security tab backup/restore round-trips without losing scenario height.
18. **Perccent independence** — Standalone Perccent Wallet imports peer ledger without overwriting local credentials; session timeout and logout behave per tests.
19. **Registration alignment** — New Evolve user registration adopts seed ledger, aligns chain tip, and publishes rendezvous address.
20. **Backup and recovery** — Export encrypted backup from Security tab; restore on blank device recovers balances and username via seed envelope fetch.

## 6. Release installers and download integrity

21. **Checksum verify** — Download `.exe`/`.apk` and matching `.sha256` from GitHub Releases or gh-pages; hash must match sidecar before install.
22. **Windows install** — Run `evolve-v*-windows-x64-setup.exe` or `perccent-wallet-v*-windows-x64-setup.exe`; app launches, version badge matches release.
23. **Android install** — Install APK; package id is `com.evolve.chronoflux` or `com.perccent.perccent_wallet`; `versionCode` exceeds prior published build.
24. **Post-install sync** — Fresh install connects to configured seed in `assets/config/perc_network.json` and syncs without credential errors.

## 7. Security and operational checks

25. **run security audit** — From workspace root: `powershell -File run_security_audit.ps1`; both repos log `run_security_audit=PASS` (artifact scan may skip if no local `build/downloads`).
26. **Defender on artifacts** — After building installers, re-run security audit; logs must show `defender: CLEAN` or documented `UNAVAILABLE` with integrity OK.
27. **Dependency exceptions** — If audit reports `PASS_WITH_DOCUMENTED_EXCEPTIONS`, confirm `EX-*` ids exist in `SECURITY.md` with rationale.

---

*Last updated for Evolve v4.0.6+151 and Perccent Wallet v1.0.6+4 automated suites.*