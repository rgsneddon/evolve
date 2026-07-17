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

Minimum Android: API 24 (Android 7.0)
  (Flutter default minSdk; matches the APK badging sdkVersion.)

ABIs note: fat APK includes arm64-v8a, armeabi-v7a, and x86_64 only.
  32-bit x86 emulators are not supported.

Direct download URL pattern (GitHub Releases; binaries are not hosted on gh-pages):
  https://github.com/rgsneddon/evolve/releases/download/v{version}/evolve-v{version}-android-setup.apk

Checksum sidecars (SHA-256 minimum, SHA-512 included):
  evolve-v{version}-android-setup.apk.sha256
  evolve-v{version}-android-setup.apk.sha512
  CHECKSUMS.sha256 / CHECKSUMS.sha512 / checksums.json