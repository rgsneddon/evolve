# Evolve macOS signing inputs

Bundle ID: `com.evolve.chronoflux` (see `Runner/Configs/AppInfo.xcconfig`).

## Required Apple inputs

| Input | Where used |
|-------|------------|
| Apple Developer Program membership | Notarization / distribution |
| Team ID (`DEVELOPMENT_TEAM`) | Xcode project Signing & Capabilities |
| Developer ID Application certificate | Direct distribution (DMG/zip outside App Store) |
| Or Mac App Store distribution cert + profile | App Store path |

Team ID for this machine’s Apple Developer account is already wired into
`Runner/Configs/AppInfo.xcconfig` and the Xcode project as `SFCBP95595`
(Russell Sneddon). Release builds use **Developer ID Application**; Debug uses
**Apple Development**. Override locally if needed:

```bash
export DEVELOPMENT_TEAM=SFCBP95595
```

Or open `macos/Runner.xcworkspace` in Xcode → Runner target → Signing & Capabilities.

## Entitlements

- Sandbox enabled (`macos/Runner/Release.entitlements`)
- Outbound network client (PERC / update checks)
- User-selected file read/write (backup / restore)
- Camera (optional QR scan on desktop webcams)

## Build command (macOS + Xcode only)

```bash
# From evolve_app root on a Mac
flutter build macos --release
```

Package for the Windows release pipeline:

```powershell
./scripts/build_macos_installer.ps1
# or after a local flutter build:
./scripts/build_macos_installer.ps1 -SkipMacosBuild
```

Output paths:

| Artifact | Path |
|----------|------|
| Flutter app | `build/macos/Build/Products/Release/Evolve.app` |
| Versioned zip | `build/downloads/v{version}/evolve-v{version}-macos-x64.zip` |
| Metadata | `installer/macos/evolve-v{version}-macos.json` |

## Notarization (required for Gatekeeper on other Macs)

Release builds use **Developer ID Application** + **hardened runtime** + secure timestamp.
Without notarization, `spctl` reports `Unnotarized Developer ID` and other users may see
“Apple cannot check it for malicious software.”

### One-time: App Store Connect API key for notarytool

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
2. Create a key with **Developer** (or Admin) access → download `AuthKey_XXXXXXXXXX.p8` once
3. Note **Key ID** and **Issuer ID** (UUID) — team keys need both

Store credentials in the keychain:

```bash
xcrun notarytool store-credentials "evolve-notary" \
  --key ~/Downloads/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer "YOUR-ISSUER-UUID-HERE"
```

### Build, notarize, staple

```bash
cd /path/to/evolve
export DEVELOPMENT_TEAM=SFCBP95595
flutter build macos --release

# Package
ditto -c -k --keepParent --sequesterRsrc \
  build/macos/Build/Products/Release/Evolve.app \
  build/downloads/v4.1.8/evolve-v4.1.8-macos-x64.zip

# Submit + wait
xcrun notarytool submit build/downloads/v4.1.8/evolve-v4.1.8-macos-x64.zip \
  --keychain-profile "evolve-notary" --wait

# Staple ticket onto the app, then re-zip
xcrun stapler staple build/macos/Build/Products/Release/Evolve.app
spctl --assess --type execute -v build/macos/Build/Products/Release/Evolve.app
# expect: accepted

ditto -c -k --keepParent --sequesterRsrc \
  build/macos/Build/Products/Release/Evolve.app \
  build/downloads/v4.1.8/evolve-v4.1.8-macos-x64.zip
```

Individual API keys may omit `--issuer`; team keys require it. A `401 Unauthenticated`
error usually means missing/wrong Issuer ID or Key ID.
