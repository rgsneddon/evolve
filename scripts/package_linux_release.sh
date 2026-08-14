#!/usr/bin/env bash
# Package flutter build/linux/x64/release/bundle as evolve-vVERSION-linux-x64.tar.gz
# and a best-effort Arch .pkg.tar.zst. Run on Linux after: flutter build linux --release
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-4.1.10}"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
OUT="$ROOT/build/downloads/v${VERSION}"
mkdir -p "$OUT"
if [[ ! -x "$BUNDLE/evolve" ]]; then
  echo "missing $BUNDLE/evolve — run flutter build linux --release first" >&2
  exit 1
fi
STAGE="$ROOT/build/installer/linux/evolve"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -a "$BUNDLE/." "$STAGE/"
if [[ -f "$ROOT/linux/packaging/evolve.desktop" ]]; then
  cp "$ROOT/linux/packaging/evolve.desktop" "$STAGE/evolve.desktop"
fi
TAR="$OUT/evolve-v${VERSION}-linux-x64.tar.gz"
tar -C "$(dirname "$STAGE")" -czf "$TAR" evolve
( cd "$OUT" && shasum -a 256 "$(basename "$TAR")" > "$(basename "$TAR").sha256" )

# Arch package: /opt/evolve + /usr/bin/evolve
ARCH_ROOT="$ROOT/build/installer/arch/pkg"
rm -rf "$ARCH_ROOT"
mkdir -p "$ARCH_ROOT/opt/evolve" "$ARCH_ROOT/usr/bin" "$ARCH_ROOT/usr/share/applications"
cp -a "$STAGE/." "$ARCH_ROOT/opt/evolve/"
ln -s /opt/evolve/evolve "$ARCH_ROOT/usr/bin/evolve"
if [[ -f "$STAGE/evolve.desktop" ]]; then
  cp "$STAGE/evolve.desktop" "$ARCH_ROOT/usr/share/applications/evolve.desktop"
fi
ARCH_PKG="$OUT/evolve-v${VERSION}-archlinux-x86_64.pkg.tar.zst"
if command -v zstd >/dev/null 2>&1; then
  tar -C "$ARCH_ROOT" -cf - . | zstd -q -o "$ARCH_PKG"
else
  # fallback gzip-named as .pkg.tar.gz if zstd missing
  ARCH_PKG="$OUT/evolve-v${VERSION}-archlinux-x86_64.pkg.tar.gz"
  tar -C "$ARCH_ROOT" -czf "$ARCH_PKG" .
fi
( cd "$OUT" && shasum -a 256 "$(basename "$ARCH_PKG")" > "$(basename "$ARCH_PKG").sha256" )
cp "$ROOT/linux/packaging/PKGBUILD" "$OUT/PKGBUILD" 2>/dev/null || true
echo "linux=$TAR"
echo "arch=$ARCH_PKG"
