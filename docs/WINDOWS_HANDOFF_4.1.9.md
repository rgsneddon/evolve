# Windows handoff — Evolve Chronoflux **4.1.9** (build **177**)

**Audience:** Windows x64 build operator.  
**Mac has already built** Android / macOS / iOS / web under `downloads/v4.1.9/`.  
**You must native-rebuild Windows** (and Linux if shipping from a Linux agent). Do not rename an older EXE as 4.1.9.

## Product truth in this pin

| Item | Value |
|------|--------|
| Version | `4.1.9+177` (`pubspec.yaml`) |
| Perccent seed | `https://135.181.152.10.sslip.io/perc` |
| Genesis | `networkGenesisRevision: 2` |
| Render | **Paused** — do not ship APKs/EXEs that still point at `evolve-perc-internet.onrender.com` |
| Scenario rewards | Treasury rematerialize after public ledger import (so faucet can debit `evolve_treasury`) |

## Mac staging inventory (already done)

```
downloads/v4.1.9/
  evolve-v4.1.9-android-setup.apk
  evolve-v4.1.9-macos-x64.zip
  evolve-v4.1.9-ios-setup.ipa
  evolve-v4.1.9-web.zip
  *.sha256
  manifest.json
```

Git pull **main** before freezing Windows so you get Helsinki seed + reward rematerialize.

## Windows PE — ordered steps

```bat
cd /d %EVOLVE_REPO%
git fetch origin
git checkout main
git pull origin main

type pubspec.yaml | findstr version
rem MUST show: version: 4.1.9+177

type assets\config\perc_network.json
rem MUST contain: 135.181.152.10.sslip.io/perc
rem MUST NOT contain: onrender.com as rendezvousUrl

pwsh -File scripts\build_windows_installer.ps1 -Version 4.1.9 -Build 177
```

**Exact basenames to produce:**

```text
downloads\v4.1.9\evolve-v4.1.9-windows-x64-setup.exe
downloads\v4.1.9\evolve-v4.1.9-windows-x64.zip   (portable, if script emits it)
```

Attach SHA-256 next to each file. Sign with your usual Windows code-sign flow.

## Linux (optional, Linux host only)

```bash
flutter build linux --release --build-name=4.1.9 --build-number=177
# package tarball → downloads/v4.1.9/evolve-v4.1.9-linux-x64.tar.gz
```

Mac cannot build Linux.

## Publish

1. Upload all of `downloads/v4.1.9/*` to GitHub Release **v4.1.9** (replace stale Android if needed).
2. Update gh-pages downloads index if that pipeline is used.
3. Confirm in-app update JSON points at 4.1.9 build **177** when ready.

## Smoke after Windows install

1. Install EXE on a clean machine.
2. Open Perccent wallet → force sync → height should be **> 0** (Helsinki tip, not stuck at 0).
3. Run a scenario (respect 7‑minute faucet cooldown) → user receives **xx/100 PERC**.
4. If height still 0: uninstall old build first; confirm no leftover Render pin.

## Do not

- Rename 4.1.8 EXE as 4.1.9.
- Ship with Render rendezvous.
- Drop treasury rematerialize (users get **treasuryEmpty** without it).
