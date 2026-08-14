# Windows handoff — Evolve Chronoflux **4.1.10** (build **176**)

**Audience:** operator at a **Windows x64** machine with Visual Studio C++.  
**Do not** rename an older EXE or zip as 4.1.10.  
**Do not** treat the already-published portable zip as Authenticode-signed.

Durable how-to (tools, Inno, SignPath, publish rules):
[WINDOWS_BUILDS.md](WINDOWS_BUILDS.md). This file is the **4.1.10 pin**.

---

## 1. What is already shipped (no Windows machine required)

Published latest release (immutable — you **cannot** attach more files to it):

**https://github.com/rgsneddon/evolve/releases/tag/v4.1.10-platforms**

| Platform | Asset | Built on |
|---|---|---|
| macOS | `evolve-v4.1.10-macos-x64.zip` | Mac |
| iOS | `evolve-v4.1.10-ios-setup.ipa` | Mac |
| Linux x64 | `evolve-v4.1.10-linux-x64.tar.gz` | Helsinki Ubuntu (`flutter build linux`) |
| Arch Linux | `evolve-v4.1.10-archlinux-x86_64.pkg.tar.zst` + `PKGBUILD` | Helsinki (staged from the Linux bundle) |
| Android | `evolve-v4.1.10-android-setup.apk` | same APK as tag `v4.1.10` |
| Windows x64 **portable** | `evolve-v4.1.10-windows-x64.zip` | GitHub `windows-latest` via `flutter build windows --release` |

Each binary has a `.sha256` sidecar.

`v4.1.10` itself is Android-only and also immutable. Ignore it for new uploads.

### Shipped Windows zip (unsigned portable)

| Item | Value |
|---|---|
| File | `evolve-v4.1.10-windows-x64.zip` |
| SHA-256 | `137597c94980d14f63088c5349ab0782addbc9eede1505c69fbd2fd47da5fcb1` |
| Layout | Flutter Release folder at zip root (`evolve.exe`, `flutter_windows.dll`, `data\`, plugins) |
| `evolve.exe` | PE (`MZ`), ~60 KB runner |
| `data\app.so` | ~10 MB AOT |
| `flutter_windows.dll` | ~21 MB |
| Authenticode | **none** |
| Inno `setup.exe` | **not produced** |

That zip is a real 4.1.10+176 PE. It is **not** the signed installer the
downloads page historically advertises as `evolve-v*-windows-x64-setup.exe`.

---

## 2. What you must still do on Windows

| # | Deliverable | Why Windows |
|---|---|---|
| A | Rebuild PE from the official git pin (optional but preferred before signing) | `flutter build windows` needs MSVC |
| B | `evolve-v4.1.10-windows-x64-setup.exe` (Inno) | `ISCC.exe` is Windows-only |
| C | Authenticode-sign `evolve.exe`, every `Release\*.dll`, and the setup.exe | `signtool` |
| D | Re-zip portable `evolve-v4.1.10-windows-x64.zip` from the **signed** Release folder | zip after sign, not before |
| E | SHA-256 (and SHA-512 if you run the installer script) sidecars | produced by the scripts |
| F | Publish a **new** release tag (see §8) | `v4.1.10-platforms` will 422 |
| G | (Optional) Fix + run SignPath workflow | needs `workflow` PAT + Windows runner |

Linux / Arch / macOS / iOS / Android are **done**. Do not rebuild them on
Windows unless you are deliberately replacing a broken file.

---

## 3. Product truth in this pin

| Item | Value |
|---|---|
| Marketing version | `4.1.10` |
| Build number | `176` |
| `pubspec.yaml` | `version: 4.1.10+176` |
| Source tag (code) | `v4.1.10` = `a889d0c` |
| Packaging tag (linux/ + scripts) | `v4.1.10-platforms` / `release/4.1.10-build178` = `754532d` |
| Perccent rendezvous | `https://135.181.152.10.sslip.io/perc` |
| Genesis | `networkGenesisRevision: 2` |
| Render | **Paused** — `rendezvousUrl` must not be `onrender.com` |
| Scenario rewards | Treasury rematerialize after public ledger import |

**Checkout `v4.1.10-platforms` (754532d), not `main`.** `main` is a different
line (Apple 4.1.8 packaging and later security work). Building `main` will
not freeze 4.1.10+176.

```bat
cd /d %EVOLVE_REPO%
git fetch origin --tags
git checkout --detach v4.1.10-platforms
git rev-parse --short HEAD
rem MUST print: 754532d

findstr /b version pubspec.yaml
rem MUST print: version: 4.1.10+176

findstr sslip assets\config\perc_network.json
findstr onrender assets\config\perc_network.json
rem sslip MUST hit; onrender may appear only in a comment, never as rendezvousUrl
```

---

## 4. Patch the tree before the first compile

`754532d` / `v4.1.10` do **not** contain the MSVC 14.51+ silence flags.
Without them, `flutter build windows` fails here:

```
error C2338: STL1011 ... <experimental/coroutine> ...
  plugins\local_auth_windows\local_auth_windows_plugin.vcxproj
  plugins\permission_handler_windows\permission_handler_windows_plugin.vcxproj
```

### 4a. Create `Directory.Build.props` at the repo root

```xml
<Project>
  <!-- MSVC 14.51+ treats <experimental/coroutine> as an error. Flutter plugins
       local_auth_windows and permission_handler_windows still include it. -->
  <ItemDefinitionGroup>
    <ClCompile>
      <PreprocessorDefinitions>_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
    </ClCompile>
  </ItemDefinitionGroup>
</Project>
```

### 4b. Edit `windows/CMakeLists.txt`

Immediately after `add_definitions(-DUNICODE -D_UNICODE)` add:

```cmake
add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
```

Inside `function(APPLY_STANDARD_SETTINGS TARGET)`, after the `_DEBUG` line, add:

```cmake
  target_compile_definitions(${TARGET} PRIVATE "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")
```

If this handoff was committed on a later `docs/windows-*` branch, `git merge`
or cherry-pick that commit instead of pasting.

Do **not** commit `code_sign.local.env`, PFX files, or `grok_proxy.local.env`.

---

## 5. One-command freeze (unsigned, then you sign)

```bat
cd /d %EVOLVE_REPO%
flutter config --enable-windows-desktop
flutter pub get
pwsh -File scripts\build_windows_installer.ps1 -Version 4.1.10 -Build 176 -SkipCodeSign
```

If a PFX is already configured via `scripts\setup_pfx_signing.ps1`, drop
`-SkipCodeSign` and skip §6’s first paragraph.

Then wrap the Release folder as the portable zip (script does not do this):

```powershell
$ver = '4.1.10'
$rel = 'build\windows\x64\runner\Release'
$out = "build\downloads\v$ver"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$zip = Join-Path $out "evolve-v$ver-windows-x64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$rel\*" -DestinationPath $zip
Get-FileHash -Algorithm SHA256 $zip |
  ForEach-Object { "$($_.Hash.ToLower())  $(Split-Path $_.Path -Leaf)" } |
  Set-Content -Encoding ascii "$zip.sha256"
```

### Exact basenames you must produce

```
build\downloads\v4.1.10\evolve-v4.1.10-windows-x64-setup.exe
build\downloads\v4.1.10\evolve-v4.1.10-windows-x64-setup.exe.sha256
build\downloads\v4.1.10\evolve-v4.1.10-windows-x64.zip
build\downloads\v4.1.10\evolve-v4.1.10-windows-x64.zip.sha256
```

Optional (installer script already writes these if signing ran):

```
evolve-v4.1.10-windows-x64-setup.exe.sha512
```

### Accept gate before signing

```powershell
$exe = 'build\windows\x64\runner\Release\evolve.exe'
$dll = 'build\windows\x64\runner\Release\flutter_windows.dll'
$so  = 'build\windows\x64\runner\Release\data\app.so'
$setup = 'build\downloads\v4.1.10\evolve-v4.1.10-windows-x64-setup.exe'
foreach ($p in $exe,$dll,$so,$setup) { if (-not (Test-Path $p)) { throw "missing $p" } }
if ((Get-Item $dll).Length -lt 10MB) { throw 'flutter_windows.dll too small' }
if ((Get-Item $so).Length  -lt 1MB)  { throw 'data\app.so too small' }
$mz = [IO.File]::ReadAllBytes($exe)[0..1]
if ([Text.Encoding]::ASCII.GetString($mz) -ne 'MZ') { throw 'evolve.exe is not a PE' }
```

---

## 6. Sign (required for SmartScreen)

```bat
pwsh -File scripts\doctor_windows_signing.ps1
pwsh -File scripts\setup_pfx_signing.ps1 -PfxPath C:\path\to\ov.pfx -PfxPassword <password>
pwsh -File scripts\finish_windows_signing.ps1 -Version 4.1.10
pwsh -File scripts\verify_windows_signatures.ps1
```

`finish_windows_signing.ps1` rebuilds unless you pass `-SkipBuild`. After a
successful sign, **re-run the Compress-Archive block in §5** so the zip
contains signed PE files, then recompute `.sha256`.

If doctor lists SignPath as the only backend and it is not enabled, use PFX.
Do not publish an unsigned `setup.exe` as the “signed” asset.

SignPath path (after org approval): [../.signpath/SETUP.txt](../.signpath/SETUP.txt).
You must also patch the workflow PATH wipe — see
[WINDOWS_BUILDS.md](WINDOWS_BUILDS.md) §5c. The Mac OAuth token cannot push
that YAML.

---

## 7. Smoke on the Windows box

1. Uninstall any older Evolve Chronoflux.
2. Run `evolve-v4.1.10-windows-x64-setup.exe` **or** unzip the portable zip.
3. Launch. Version / build badge = **4.1.10** / **176**.
4. Perccent → force sync → chain height **> 0** (Helsinki).
5. Scenario reward still works (7-minute faucet cooldown). Height 0 usually
   means an old Render-pinned install leftover — uninstall and retry.
6. Signed build: Properties → Digital Signatures on `evolve.exe` and the
   setup.exe. `verify_windows_signatures.ps1` exit code 0.

---

## 8. Publish (new tag — old ones are frozen)

```
v4.1.10              immutable, Android only
v4.1.10-build178     immutable, macOS + iOS + Android
v4.1.10-platforms    immutable, all platforms + unsigned Windows zip
```

`gh release upload v4.1.10-platforms …` will **422**. Create a sibling tag:

```bat
gh release create v4.1.10-windows --repo rgsneddon/evolve ^
  --title "Evolve 4.1.10 — Windows signed installer" ^
  --notes-file docs\WINDOWS_HANDOFF_4.1.10.md ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64-setup.exe ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64-setup.exe.sha256 ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64.zip ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64.zip.sha256
```

Then (optional) refresh gh-pages cards:

```bat
pwsh -File scripts\deploy_downloads.ps1 -Version 4.1.10
```

---

## 9. SignPath / GHA breadcrumbs (if you stay on the Windows laptop)

Existing workflow: `.github/workflows/signpath-windows-release.yml`.  
Proposed extra workflow (not installed under `.github/workflows/`):
`scripts/ci/evolve-desktop-linux-windows.yml`.

Why the current SignPath run fails (run `31801992978` and siblings):

```
$env:Path = Machine + User     # wipes flutter-action
flutter pub get                # "flutter is not recognized"
```

`FLUTTER_ROOT` is set (`C:\hostedtoolcache\windows\flutter\stable-*\flutter`)
but is not prepended. Fix is in [WINDOWS_BUILDS.md](WINDOWS_BUILDS.md) §5c.

Pushing that YAML requires `gh auth refresh -s workflow` (or a classic PAT
with the `workflow` scope). A `repo`-only OAuth token is refused with:

```
refusing to allow an OAuth App to create or update workflow
.github/workflows/signpath-windows-release.yml without workflow scope
```

Do **not** fork a third-party Flutter repo again to get a runner. That was an
emergency path for the unsigned zip only. The official path is this machine
or a fixed SignPath workflow on `rgsneddon/evolve`.

---

## 10. Do not

- Rename `evolve-v4.1.8-windows-x64-setup.exe` (or 4.1.9, or anything else)
  to `…-v4.1.10-…`.
- Ship Render rendezvous.
- Commit `code_sign.local.env`, `*.pfx`, or `grok_proxy.local.env`.
- Upload onto `v4.1.10` / `v4.1.10-build178` / `v4.1.10-platforms`.
- Skip `Directory.Build.props` and then “fix” the failure by dropping
  `local_auth` / `permission_handler` — that changes the product.
- Publish the unsigned portable zip as if it were the new signed installer.

---

## 11. Related

| Path | Role |
|---|---|
| [WINDOWS_BUILDS.md](WINDOWS_BUILDS.md) | Full Windows runbook |
| [MAC_BUILDS.md](MAC_BUILDS.md) | Apple side (already done for 4.1.10) |
| `scripts/package_linux_release.sh` | Linux + Arch (already done on Helsinki) |
| `installer/windows/README.txt` | Short installer notes |
| `.signpath/SETUP.txt` | SignPath after approval |
