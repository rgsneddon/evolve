Evolve Chronoflux — Windows installer package
===============================================

The Windows installer is a versioned setup executable:

  evolve-v{version}-windows-x64-setup.exe

Build:
  scripts\build_windows_installer.ps1

Authenticode signing (required for release):
  Microsoft Trusted Root Program CA chain is mandatory for evolve.exe,
  all Release\ PE files (.exe, .dll), and the setup.exe installer.

  Quick setup:
    scripts\setup_pfx_signing.ps1 -PfxPath <cert.pfx> -PfxPassword <password>

  Option A — PFX from DigiCert, Sectigo, or SSL.com (recommended):
    UK individuals: OV code signing supported (no Azure identity validation needed).
    1. Purchase OV code signing certificate; export as .pfx with private key
    2. scripts\setup_pfx_signing.ps1 -PfxPath C:\path\to\cert.pfx -PfxPassword <password>
    3. scripts\finish_windows_signing.ps1

  Option B — SignPath Foundation (applied; pending approval):
    See .signpath/SETUP.txt and .github/workflows/signpath-windows-release.yml
    GitHub Actions builds unsigned setup.exe, SignPath signs on GitHub-hosted runners.
    After approval: set SIGNPATH_* secrets/vars, SIGNPATH_ENABLED=true, run workflow.

  Option C — Windows certificate store:
    Install OV/EV cert in Current User\Personal; set CODE_SIGN_MODE=store in code_sign.local.env

  Verify: scripts\verify_windows_signatures.ps1

Dev builds without a cert:
  scripts\build_windows_installer.ps1 -SkipCodeSign

Deploy (GitHub Pages):
  scripts\deploy_downloads.ps1

Architecture: x64 (64-bit Intel/AMD)

Checksum sidecars (SHA-256 minimum, SHA-512 included):
  evolve-v{version}-windows-x64-setup.exe.sha256
  evolve-v{version}-windows-x64-setup.exe.sha512
  CHECKSUMS.sha256 / CHECKSUMS.sha512 / checksums.json

Secure direct URL pattern:
  https://rgsneddon.github.io/evolve/downloads/v{version}/evolve-v{version}-windows-x64-setup.exe