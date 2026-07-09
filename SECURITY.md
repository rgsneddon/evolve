# Security policy — Evolve Chronoflux

## Release checks

Before each GitHub Release, maintainers run:

1. `scripts/scan_release_artifacts.ps1` — Defender scan + PE/APK integrity on `build/downloads/v*`
2. `scripts/audit_dependencies.ps1` — `flutter pub audit` + `npm audit --audit-level=high` in `perc_chain/`
3. `scripts/sign_download_packages.ps1` — SHA-256/SHA-512 sidecars and checksum manifest verification

## Dependency audit exceptions

Document any unmitigated **critical** or **high** findings here with rationale and planned remediation.

<!-- If `flutter pub audit` or `npm audit` report issues that cannot be fixed immediately,
list them below under "Documented exceptions". -->

### Documented exceptions

| Finding | Rationale |
|---------|-----------|
| `dart pub audit` subcommand unavailable on Dart SDK 3.12.x in this environment | SDK lacks built-in pub audit; `npm audit --audit-level=high` covers `perc_chain/` (0 high/critical at last run). Flutter dependencies are reviewed via `flutter pub outdated` snapshot captured in audit logs before each release. Upgrade SDK when `dart pub audit` ships to enable automated Dart advisory checks. |

## Reporting vulnerabilities

Email **russell.gray.sneddon@gmail.com** with reproduction steps. Do not open public issues for undisclosed security bugs.