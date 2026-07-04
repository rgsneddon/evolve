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
    scripts\setup_code_signing.ps1 -OpenAzurePortal

  Option A — Azure Trusted Signing:
    Individual Public Trust: billing country must be USA or Canada only.
    Organization Public Trust: USA, Canada, EU, or UK (registered business).
    UK developers: use Organization → Public (not Individual) on account evrgs.
    1. az login
    2. Create Artifact Signing account + identity validation + cert profile
       (Azure portal; identity review can take 1–20 business days)
       Account name rules: 3–24 chars, start with a letter, letters/numbers/hyphens
       only (no underscores). Example: evolve-codesign
    3. Copy tools\trusted-signing\metadata.json.example to metadata.json
    4. Set CODE_SIGN_MODE=azure in code_sign.local.env
    5. scripts\setup_code_signing.ps1 then scripts\build_windows_installer.ps1

  Option B — PFX from DigiCert, Sectigo, or SSL.com:
    1. Copy code_sign.local.env.example to code_sign.local.env
    2. Set CODE_SIGN_MODE=pfx, CODE_SIGN_PFX_PATH, and CODE_SIGN_PFX_PASSWORD
    3. scripts\build_windows_installer.ps1

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