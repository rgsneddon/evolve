# GitHub Releases — one section per version

**Both machines follow this.** Windows, Linux, Arch, Android, macOS, and iOS for a given version number all go on **the same GitHub Release**.

| Rule | Detail |
|------|--------|
| Tag | `vX.Y.Z` only (example: `v4.1.12`) |
| Never | `v4.1.12-windows`, `v4.1.12-macos-ios-android`, `v4.1.12-linux`, `v4.1.12-bundle` |
| Download URL | `https://github.com/rgsneddon/evolve/releases/download/vX.Y.Z/<file>` |
| Immutable releases | **Leave OFF** so the second machine can attach files |

## Who builds what

| Machine | Packages |
|---------|----------|
| **This Windows PC** | Windows setup/zip, Linux tarball, Arch `.pkg.tar.zst` |
| **Mac** | Android APK, macOS zip (Developer ID + notarize), iOS IPA |

Stage everything under `build/downloads/vX.Y.Z/` with the usual names (`evolve-vX.Y.Z-windows-x64-setup.exe`, `…-android-setup.apk`, `…-macos-x64.zip`, `…-ios-setup.ipa`, `…-linux-x64.tar.gz`, `…-archlinux-x86_64.pkg.tar.zst`) plus `.sha256` sidecars.

## Sync `main` before any package build

Both machines build from **the same `origin/main` tip**. After the Mac pushes (or after you push from the laptop), the other machine:

```powershell
git fetch origin
git checkout main
git pull origin main
```

Do not build Windows / Linux / Arch from a clone that is behind `origin/main`. The laptop learns about Mac commits only by pulling GitHub — there is no other handoff.

## Deploy order (4.1.12 and later)

1. **First machine** (whichever finishes first) creates a **draft** on `vX.Y.Z` and uploads its packages:

   ```powershell
   pwsh ./scripts/upload_release_assets.ps1 -Version 4.1.12 -Draft
   ```

2. **Second machine** uploads onto **that same tag** (do not create another release):

   ```powershell
   pwsh ./scripts/upload_release_assets.ps1 -Version 4.1.12
   ```

3. When Windows + Linux + Arch + Android + macOS + iOS (whatever you are shipping) are on the draft, publish it as Latest:

   ```powershell
   pwsh ./scripts/upload_release_assets.ps1 -Version 4.1.12 -PublishNow
   ```

`publish_github_release.ps1` also attaches to the existing `vX.Y.Z` tag if the release already exists. It strips a platform suffix if someone passes `-Version 4.1.12-windows`.

## Do not

- Delete a published release to “add a file”. GitHub can permanently reserve that tag (this is why `v4.1.11` could not be reused).
- Open a companion tag for Apple/Android/Linux.
- Turn immutable releases back on until **after** every platform for that version is already attached.

## 4.1.11 (historical)

`v4.1.11` is reserved by GitHub. The all-platform 4.1.11 files live on [`v4.1.11-bundle`](https://github.com/rgsneddon/evolve/releases/tag/v4.1.11-bundle). Do not fight that tag. **4.1.12+ uses `v4.1.12` only.**
