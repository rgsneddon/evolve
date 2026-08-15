# Mac session runbook — Evolve suite (iOS + macOS)

Use this on a Mac with Xcode when preparing real Apple artifacts. Windows can only stage, checksum, and publish.

## 0. Tools (once per Mac)

```bash
# Flutter (stable), matching the Windows workspace channel when possible
flutter doctor
# Xcode (App Store) + command-line tools
xcode-select --install
sudo xcodebuild -license accept
# CocoaPods
sudo gem install cocoapods   # or brew install cocoapods
```

Confirm:

```bash
flutter doctor -v   # iOS toolchain + Xcode must be green
```

## 1. Apple signing inputs

| App | Bundle ID | Signing notes |
|-----|-----------|---------------|
| **Evolve** iOS | `com.evolve.chronoflux` | [ios/SIGNING.md](../ios/SIGNING.md) |
| **Evolve** macOS | `com.evolve.chronoflux` | [macos/SIGNING.md](../macos/SIGNING.md) |
| **MY PERC** (perccent-wallet) iOS | see that repo’s `ios/SIGNING.md` | sibling `perccent_wallet` |
| **MY PERC** macOS | see that repo’s `macos/` AppInfo | sibling `perccent_wallet` |

Set your team for the session:

```bash
export DEVELOPMENT_TEAM=XXXXXXXXXX   # 10-char Team ID
```

Open each Xcode workspace once and select the Team if automatic signing prompts.

## 2. Evolve — iOS IPA

```bash
cd /path/to/evolve_app
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# Or package + checksum into build/downloads:
#   pwsh ./scripts/build_ios_installer.ps1
```

Expected:

- IPA: `build/ios/ipa/*.ipa`
- Versioned: `build/downloads/v{version}/evolve-v{version}-ios-setup.ipa` (after installer script)

## 3. Evolve — macOS desktop

```bash
cd /path/to/evolve_app
flutter pub get
flutter build macos --release
# Or package + zip + checksum:
#   pwsh ./scripts/build_macos_installer.ps1
```

Expected:

- App: `build/macos/Build/Products/Release/Evolve.app`
- Versioned zip: `build/downloads/v{version}/evolve-v{version}-macos-x64.zip`

## 4. MY PERC (perccent-wallet) — pointers

```bash
cd /path/to/perccent_wallet
flutter pub get
# iOS
cd ios && pod install && cd ..
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# macOS
flutter build macos --release
```

Use that repo’s packaging scripts if present (`scripts/build_*_installer.ps1`). Stage outputs under its `build/downloads/v{version}/`.

## 5. GitHub Releases — same tag as Windows (required)

**Full policy:** [GITHUB_RELEASES.md](GITHUB_RELEASES.md).

Android, macOS, and iOS for version `X.Y.Z` attach to **`vX.Y.Z` only** — the same release Windows/Linux/Arch use. Never `vX.Y.Z-macos-ios-android`.

```powershell
# After packaging on the Mac:
pwsh ./scripts/sign_download_packages.ps1 -Version {version}
pwsh ./scripts/upload_release_assets.ps1 -Version {version}          # draft if missing
# When this version is complete on both machines:
# pwsh ./scripts/upload_release_assets.ps1 -Version {version} -PublishNow
```

You may still copy Mac artifacts into the Windows clone for checksum/index updates:

```
evolve/build/downloads/v{version}/
  evolve-v{version}-ios-setup.ipa
  evolve-v{version}-macos-x64.zip
  evolve-v{version}-android-setup.apk
  *.sha256
```

Then on either machine: `./scripts/deploy_downloads.ps1 -Version {version}` (gh-pages checksums + index). Update `download.html` / downloads cards so every platform href is `…/releases/download/v{version}/…`.

## 6. Quick checks before leaving the Mac

```bash
# Evolve iOS audit (structural; also runs on Windows)
pwsh ./scripts/ios_project_audit.ps1
# Evolve macOS audit
pwsh ./scripts/macos_project_audit.ps1
```

Confirm bundle IDs remain `com.evolve.chronoflux` for both Apple platforms.

## 7. What Windows cannot do

- Compile IPA or `.app` without Xcode
- Notarize macOS apps
- Generate Apple provisioning profiles

Placeholder `*-ios-setup.ipa` files in releases are **not** production builds until replaced by a real Mac-produced IPA.
