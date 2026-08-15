# Handover — Evolve **4.2.1** Linux + Arch Linux

**Audience:** Windows-laptop operator building Linux/Arch (or a USB-booted Linux box).  
**Pin:** `4.2.1+181`  
**GitHub tag:** **`v4.2.1` only** — never `v4.2.1-linux` or `v4.2.1-arch`.  
**Machine split:** this laptop produces Windows + Linux + Arch. The Mac produces Android + macOS + iOS (including iPad via the universal IPA). See [MACHINE_SPLIT.md](MACHINE_SPLIT.md) and [GITHUB_RELEASES.md](GITHUB_RELEASES.md).

This Windows session cannot produce Linux/Arch packages. Build them on Linux (native or USB live). Boot-USB path: [scripts/linux/BOOT-THIS-PC.md](../scripts/linux/BOOT-THIS-PC.md).

## Package basenames

Stage under `build/downloads/v4.2.1/` (plus `.sha256`):

| Distro | Basename |
|--------|----------|
| Generic Linux x64 | `evolve-v4.2.1-linux-x64.tar.gz` |
| Arch Linux x86_64 | `evolve-v4.2.1-archlinux-x86_64.pkg.tar.zst` |
| Windows (this laptop, already in the split) | `evolve-v4.2.1-windows-x64-setup.exe` |

## Linux tarball (Ubuntu / generic)

On a Linux host with Flutter (stable) and GTK build deps:

```bash
cd /path/to/evolve
git fetch origin && git checkout main && git pull
grep '^version:' pubspec.yaml   # MUST be 4.2.1+181

sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter pub get
flutter build linux --release --build-name=4.2.1 --build-number=181

# Package the bundle:
mkdir -p build/downloads/v4.2.1
tar -C build/linux/x64/release/bundle -czf \
  build/downloads/v4.2.1/evolve-v4.2.1-linux-x64.tar.gz .
sha256sum build/downloads/v4.2.1/evolve-v4.2.1-linux-x64.tar.gz \
  > build/downloads/v4.2.1/evolve-v4.2.1-linux-x64.tar.gz.sha256
```

## Arch Linux (`.pkg.tar.zst`)

On Arch (or the same USB path with `pacman`):

```bash
cd /path/to/evolve
grep '^version:' pubspec.yaml   # MUST be 4.2.1+181

sudo pacman -S --needed clang cmake ninja pkgconf gtk3
flutter pub get
flutter build linux --release --build-name=4.2.1 --build-number=181

# If a PKGBUILD exists in-tree, use it; otherwise wrap the same bundle:
#   evolve-v4.2.1-archlinux-x86_64.pkg.tar.zst
mkdir -p build/downloads/v4.2.1
# makepkg -f   # when packaging with a PKGBUILD
# cp *.pkg.tar.zst build/downloads/v4.2.1/evolve-v4.2.1-archlinux-x86_64.pkg.tar.zst
```

USB boot reminder (Windows PC, does not erase Windows if you pick **Try Ubuntu**):

1. Write Ubuntu ISO per [BOOT-THIS-PC.md](../scripts/linux/BOOT-THIS-PC.md).
2. Restart → F12 → USB → **Try Ubuntu**.
3. Install Flutter + clone `evolve`, then the commands above.

## Attach to the same tag

```powershell
# From the laptop after Linux/Arch files are in build/downloads/v4.2.1/
pwsh ./scripts/upload_release_assets.ps1 -Version 4.2.1
```

First machine to finish creates the **draft** on `v4.2.1`; the other machine uploads onto that tag. Publish only when Windows + Linux + Arch + Android + macOS + iOS/iPad IPA are present.

## Do not

- Invent Linux/Arch artifacts on Windows.
- Open `v4.2.1-linux`.
- Block the Mac Apple ship waiting for Arch if the draft can stay unpublished until both sides attach.
