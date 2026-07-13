Evolve VPN bundle (Windows installer payload)
=============================================

Staged at build time into {app}\vpn\ beside evolve.exe:

  wireguard.exe   — WireGuard for Windows tunnel service (redistributed from official MSI)
  wg.exe          — WireGuard CLI helper
  demo1.conf      — full-tunnel profile for Vultr VPN-RASKUL (copied from operator secrets at build; NOT in git)
  bundle.manifest.json — packaging audit metadata

Post-install copies demo1.conf to %LOCALAPPDATA%\EVOLVE_TUNNEL\ when missing.

Users do not need a separate WireGuard install or external profile download.