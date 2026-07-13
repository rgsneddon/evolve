# Evolve iOS signing inputs

Bundle ID: `com.evolve.chronoflux` (see `Runner.xcodeproj`).

## Required Apple inputs

| Input | Where used |
|-------|------------|
| Apple Developer Program membership | Distribution / ad-hoc IPA export |
| Team ID (`DEVELOPMENT_TEAM`) | Xcode project + `ExportOptions.plist` |
| Distribution certificate | Release IPA signing |
| Provisioning profile for `com.evolve.chronoflux` | `flutter build ipa` export |

Set Team ID locally:

```bash
export DEVELOPMENT_TEAM=XXXXXXXXXX
```

Or pass via Xcode → Runner target → Signing & Capabilities.

## Export options

`ios/ExportOptions.plist` defaults to `development` for local sideload testing.
For TestFlight/App Store, replace `method` with `app-store` and use a matching profile.

## Build command (macOS + Xcode only)

```powershell
.\scripts\build_ios_installer.ps1
```

On Windows, use `.\scripts\build_installers.ps1` (skips IPA compile; packages staged IPA if present).