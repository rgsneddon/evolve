Evolve Chronoflux — Android installer package
==============================================

The Android "installer" is a versioned release APK:

  evolve-v{version}-android-setup.apk

Build:
  scripts\build_android_installer.ps1

Deploy (GitHub Pages):
  scripts\deploy_downloads.ps1

Architectures (fat APK):
  - arm64-v8a   (modern phones)
  - armeabi-v7a (older 32-bit ARM)
  - x86_64      (emulators / some tablets)

Minimum Android: API 23 (Android 6.0)

Secure direct URL pattern:
  https://rgsneddon.github.io/evolve/downloads/v{version}/evolve-v{version}-android-setup.apk

Checksum sidecar:
  evolve-v{version}-android-setup.apk.sha256