# Evolve iOS signing inputs

Bundle ID: `com.evolve.chronoflux` (see `Runner.xcodeproj`).

## Required Apple inputs

| Input | Where used |
|-------|------------|
| Apple Developer Program membership | Distribution / ad-hoc / TestFlight IPA export |
| Team ID (`DEVELOPMENT_TEAM`) | Xcode project + optional `ExportOptions.plist` teamID |
| Distribution certificate (Apple Distribution or iOS Distribution) | Release IPA signing |
| Provisioning profile for `com.evolve.chronoflux` | `flutter build ipa` export |

Team ID for this machine’s Apple Developer account is already wired into the Xcode project
and `ExportOptions.plist` as `SFCBP95595` (Russell Sneddon). Override locally if needed:

```bash
export DEVELOPMENT_TEAM=SFCBP95595
```

Or Xcode → open `ios/Runner.xcworkspace` → Runner target → Signing & Capabilities → Team.

## Export options

`ios/ExportOptions.plist` defaults to:

- `method` = `development` (local device / sideload testing)
- `signingStyle` = `automatic`

For TestFlight / App Store:

1. Change `method` to `app-store` (or `app-store-connect`)
2. Ensure a matching App Store provisioning profile for `com.evolve.chronoflux`
3. Optionally set `teamID` to your 10-character Team ID

For ad-hoc device install:

1. Change `method` to `ad-hoc`
2. Register device UDIDs on the profile

## Info.plist permissions (already wired)

| Key | Purpose |
|-----|---------|
| `NSCameraUsageDescription` | PERC QR scan |
| `NSFaceIDUsageDescription` | Biometric wallet unlock |

## Build command (macOS + Xcode only)

From `evolve_app` root on a Mac:

```bash
# CocoaPods (first time / after plugin changes)
cd ios && pod install && cd ..

# IPA
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Or via packaging script (stages versioned downloads + checksums):

```powershell
./scripts/build_ios_installer.ps1
```

On Windows, IPA compile is blocked. Stage a Mac-built IPA then:

```powershell
# Place *.ipa under build/ios/ipa/ then:
./scripts/build_ios_installer.ps1 -SkipIosBuild
```

## Artifact paths

| Artifact | Path |
|----------|------|
| Flutter IPA | `build/ios/ipa/*.ipa` |
| Versioned package | `build/downloads/v{version}/evolve-v{version}-ios-setup.ipa` |
| Metadata | `installer/ios/evolve-v{version}-ios.json` |
| Checksums | `*.sha256` / `*.sha512` next to the package |

## Handoff to Windows release pipeline

1. Copy the versioned IPA + sidecars into the Windows clone’s `build/downloads/v{version}/` (or re-run `build_ios_installer.ps1 -SkipIosBuild` there).
2. Run `./scripts/sign_download_packages.ps1 -Version {version}` if needed.
3. Publish with existing GitHub Release / `deploy_downloads.ps1` flows (binaries on Releases; gh-pages hosts checksums/index).

See also: [docs/MAC_BUILDS.md](../docs/MAC_BUILDS.md) for the full suite Mac runbook.
