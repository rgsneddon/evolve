# Handover — Evolve **4.2.1** Apple (macOS + iOS + iPad)

**Audience:** new MacBook operator. SSH/Helsinki keys may not exist yet — this page does not assume `ssh helsinki` works.

**Pin:** `4.2.1+181` (`pubspec.yaml` / `PercAppVersion.current`)  
**GitHub tag:** **`v4.2.1` only** — never `v4.2.1-macos`, `v4.2.1-ios`, or `v4.2.1-macos-ios-android`.  
**Machine split:** this Mac builds Android + macOS + iOS. The Windows laptop builds Windows + Linux + Arch. See [MACHINE_SPLIT.md](MACHINE_SPLIT.md) and [GITHUB_RELEASES.md](GITHUB_RELEASES.md).

## Who builds what

| This Mac produces | Basename under `build/downloads/v4.2.1/` |
|-------------------|------------------------------------------|
| Android APK | `evolve-v4.2.1-android-setup.apk` |
| macOS zip (Developer ID + notarize) | `evolve-v4.2.1-macos-x64.zip` |
| **iOS + iPad IPA** (one universal binary) | `evolve-v4.2.1-ios-setup.ipa` |

iPad is **not** a second IPA. The iOS product is already universal: `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad) and `UISupportedInterfaceOrientations~ipad` is declared in `ios/Runner/Info.plist`. Sideload or TestFlight the same `evolve-v4.2.1-ios-setup.ipa` onto iPhone **and** iPad.

## Team / bundle

| Item | Value |
|------|--------|
| Bundle ID (iOS + macOS) | `com.evolve.chronoflux` |
| Team ID | `SFCBP95595` (Russell Sneddon) — override with `export DEVELOPMENT_TEAM=…` |
| iOS signing notes | [ios/SIGNING.md](../ios/SIGNING.md) |
| macOS signing notes | [macos/SIGNING.md](../macos/SIGNING.md) |
| Mac runbook | [MAC_BUILDS.md](MAC_BUILDS.md) |

New MacBook first-time: install Flutter (stable), Xcode + CLT, CocoaPods, accept the Xcode license. Open `ios/Runner.xcworkspace` and `macos/Runner.xcworkspace` once and pick the Team if automatic signing prompts. Helsinki SSH is **not** required to compile Apple packages.

## Commands (repo scripts)

```bash
cd /path/to/evolve
git fetch origin && git checkout main && git pull
# Confirm pin:
grep '^version:' pubspec.yaml   # MUST be 4.2.1+181

export DEVELOPMENT_TEAM=SFCBP95595

# Android (this Mac)
pwsh ./scripts/build_android_installer.ps1

# iOS + iPad (universal IPA)
flutter pub get
(cd ios && pod install)
pwsh ./scripts/build_ios_installer.ps1
# or: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

# macOS
pwsh ./scripts/build_macos_installer.ps1
# then notarize per macos/SIGNING.md / scripts/seal_macos_evolve.py
```

Expected outputs:

```
build/downloads/v4.2.1/evolve-v4.2.1-android-setup.apk
build/downloads/v4.2.1/evolve-v4.2.1-ios-setup.ipa
build/downloads/v4.2.1/evolve-v4.2.1-macos-x64.zip
```

plus `.sha256` sidecars from the installer scripts.

## Attach to GitHub (same tag as the laptop)

```powershell
pwsh ./scripts/sign_download_packages.ps1 -Version 4.2.1
pwsh ./scripts/upload_release_assets.ps1 -Version 4.2.1 -Draft
# After Windows + Linux + Arch are also on this draft:
# pwsh ./scripts/upload_release_assets.ps1 -Version 4.2.1 -PublishNow
```

Do not create a platform-suffix tag. Immutable releases stay **off** until every platform for 4.2.1 is attached.

## iPad check after the IPA exists

1. Install `evolve-v4.2.1-ios-setup.ipa` on an iPad (sideload / TestFlight).
2. App should launch full-screen (not iPhone-scaled-only). Rotate: portrait + landscape should follow `UISupportedInterfaceOrientations~ipad`.
3. Run a scenario / open Perccent wallet the same as iPhone.

## Do not

- Fake notarize or upload from Windows.
- Assume Helsinki SSH works on a new MacBook (set keys first; see operator SSH notes).
- Ship a separate iPad-only binary.
