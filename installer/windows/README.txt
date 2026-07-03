Evolve Chronoflux — Windows installer package
===============================================

The Windows installer is a versioned setup executable:

  evolve-v{version}-windows-x64-setup.exe

Build:
  scripts\build_windows_installer.ps1

Deploy (GitHub Pages):
  scripts\deploy_downloads.ps1

Architecture: x64 (64-bit Intel/AMD)

Checksum sidecars (SHA-256 minimum, SHA-512 included):
  evolve-v{version}-windows-x64-setup.exe.sha256
  evolve-v{version}-windows-x64-setup.exe.sha512
  CHECKSUMS.sha256 / CHECKSUMS.sha512 / checksums.json

Secure direct URL pattern:
  https://rgsneddon.github.io/evolve/downloads/v{version}/evolve-v{version}-windows-x64-setup.exe