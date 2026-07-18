Evolve Chronoflux — macOS installer package
==========================================

The macOS package is a zip of the release Evolve.app:

  evolve-v{version}-macos-x64.zip

Build (macOS + Xcode only):
  scripts\build_macos_installer.ps1

Stage without recompiling (after flutter build macos on a Mac):
  scripts\build_macos_installer.ps1 -SkipMacosBuild

Output paths:
  build\macos\Build\Products\Release\Evolve.app
  build\downloads\v{version}\evolve-v{version}-macos-x64.zip
  installer\macos\evolve-v{version}-macos.json

Direct download URL pattern (GitHub Releases):
  https://github.com/rgsneddon/evolve/releases/download/v{version}/evolve-v{version}-macos-x64.zip

See docs\MAC_BUILDS.md for the full suite Mac runbook.
