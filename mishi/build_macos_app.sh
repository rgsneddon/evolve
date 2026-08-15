#!/bin/bash
# Build a Mac Mishi.app from the Flutter macos target (desktop only).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
flutter build macos -t lib/mishi_main.dart --release
SRC="$ROOT/build/macos/Build/Products/Release/Evolve.app"
if [[ ! -d "$SRC" ]]; then
  SRC="$(find "$ROOT/build/macos" -name '*.app' | head -n 1)"
fi
DEST_DIR="$ROOT/build/mishi"
mkdir -p "$DEST_DIR"
if [[ -n "${SRC:-}" && -d "$SRC" ]]; then
  rm -rf "$DEST_DIR/Mishi.app" "$ROOT/mishi/Mishi.app"
  cp -R "$SRC" "$DEST_DIR/Mishi.app"
  cp -R "$SRC" "$ROOT/mishi/Mishi.app"
  ICNS="$ROOT/mishi/icons/Mishi.icns"
  for APP in "$DEST_DIR/Mishi.app" "$ROOT/mishi/Mishi.app"; do
    # Unique identity so Launch Services does not open Evolve.app.
    MACOS_DIR="$APP/Contents/MacOS"
    if [[ -f "$MACOS_DIR/Evolve" && ! -f "$MACOS_DIR/Mishi" ]]; then
      mv "$MACOS_DIR/Evolve" "$MACOS_DIR/Mishi"
    fi
    /usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Mishi' "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.evolve.mishi' "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName MISHI' "$APP/Contents/Info.plist" || true
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName MISHI' "$APP/Contents/Info.plist" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string MISHI' "$APP/Contents/Info.plist" || true
    if [[ -f "$ICNS" ]]; then
      cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
    fi
    xattr -cr "$APP" || true
    codesign --force --deep --sign - "$APP"
  done
  # Never leave a credentials txt next to the .app — Desktop is the only copy.
  rm -f "$DEST_DIR/mishi_credentials.txt" "$ROOT/mishi/mishi_credentials.txt"
  echo "built=$DEST_DIR/Mishi.app"
  echo "copied=$ROOT/mishi/Mishi.app"
else
  echo "flutter macos .app not found under build/macos" >&2
  exit 1
fi
