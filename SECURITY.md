# Security policy — Evolve Chronoflux

## Release checks

Before each GitHub Release, maintainers run:

1. **`run security audit`** — `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_security_audit.ps1` (or workspace `run_security_audit.ps1` for both repos)
2. `scripts/scan_release_artifacts.ps1` — Defender scan + PE/APK integrity on `build/downloads/v*`
3. `scripts/audit_dependencies.ps1` — `flutter pub audit` + `npm audit --audit-level=high` in `perc_chain/`
4. `scripts/sign_download_packages.ps1` — SHA-256/SHA-512 sidecars and checksum manifest verification

**Regular checks:** Run **run security audit** weekly or before any release publish. Manual device/network QA steps live in [MANUAL_TESTS.md](MANUAL_TESTS.md).

## Dependency audit exceptions

Document any unmitigated **critical** or **high** findings here with rationale and planned remediation.

<!-- If `flutter pub audit` or `npm audit` report issues that cannot be fixed immediately,
list them below under "Documented exceptions". -->

### Documented exceptions

| Exception ID | Rationale |
|--------------|-----------|
| EX-dart_pub_audit_unavailable | Dart SDK 3.12.x lacks `dart pub audit`; `npm audit --audit-level=high` covers `perc_chain/`; `flutter pub outdated` snapshot is captured in audit logs before each release until SDK supports pub audit. |

## Reporting vulnerabilities

Email **russell.gray.sneddon@gmail.com** with reproduction steps. Do not open public issues for undisclosed security bugs.