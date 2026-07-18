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

## Notarization (later Mac session)

After packaging a zip/DMG, notarize with `xcrun notarytool` and staple. Details depend on your Developer ID cert; not required for local smoke tests.
