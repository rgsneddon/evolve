# Windows session runbook — Evolve (PE + Inno installer + Authenticode)

Use this on a **Windows x64** machine. macOS and Linux cannot produce a real
`evolve.exe` PE, cannot run Inno Setup (`ISCC.exe`), and cannot Authenticode-sign
with `signtool`. Apple and Linux artifacts are documented in
[MAC_BUILDS.md](MAC_BUILDS.md) and `scripts/package_linux_release.sh`.

Per-release pin (exact tag, hashes, leftover work):
[WINDOWS_HANDOFF_4.1.10.md](WINDOWS_HANDOFF_4.1.10.md).

## 0. What only Windows can do

| Artifact | Host | Script / command |
|---|---|---|
| `evolve.exe` + plugin DLLs + `flutter_windows.dll` + `data/` | Windows x64 + VS C++ | `flutter build windows --release` or `scripts\build.ps1 windows` |
| Portable zip `evolve-v{ver}-windows-x64.zip` | Windows (or zip the Release folder after a Windows build) | `Compress-Archive` — `build_windows_installer.ps1` does **not** emit this |
| Inno installer `evolve-v{ver}-windows-x64-setup.exe` | Windows + Inno Setup 6 | `scripts\build_windows_installer.ps1` |
| Authenticode on every PE (`evolve.exe`, `*.dll`, `setup.exe`) | Windows + `signtool` | `scripts\finish_windows_signing.ps1` |
| Signature verification | Windows | `scripts\verify_windows_signatures.ps1` |
| SignPath CI (GitHub-hosted `windows-latest`) | GitHub Actions | `.github/workflows/signpath-windows-release.yml` |

Do **not** rename an older `setup.exe` or zip as the new version.

## 1. Tools (once per Windows machine)

Need **x64**. ARM64 Windows can run x64 VS tools, but ship **x64** PE (`build\windows\x64\runner\Release`).

```bat
winget install -e --id Git.Git
winget install -e --id GitHub.cli
winget install -e --id JRSoftware.InnoSetup
```

Visual Studio 2022 **or** 18 (VS 2026) with workload **Desktop development with C++**
(MSVC, Windows 10/11 SDK, CMake). Flutter will not compile the runner without it.

Flutter **stable**, same channel as the rest of the release:

```bat
flutter channel stable
flutter upgrade
flutter config --enable-windows-desktop
flutter doctor -v
```

`flutter doctor -v` must show a green **Visual Studio** line. If it is missing,
open Visual Studio Installer and add the C++ desktop workload.

Confirm Inno:

```bat
dir "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
dir "%ProgramFiles%\Inno Setup 6\ISCC.exe"
```

Confirm GitHub CLI auth (`repo` scope; `workflow` scope only if you will edit
`.github/workflows/*.yml`):

```bat
gh auth status
```

## 2. MSVC 14.51+ coroutine landmine (will fail the build if missing)

On Visual Studio 18 / MSVC 14.51+, these plugins still include
`<experimental/coroutine>` and the compile dies with **STL1011 / C2338**:

- `local_auth_windows`
- `permission_handler_windows`

The repo must contain **both**:

1. Root `Directory.Build.props` (MSBuild picks this up for every generated
   `vcxproj` under `build\windows\`, including plugins).
2. The `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` define in
   `windows/CMakeLists.txt` (`add_definitions` **and** `APPLY_STANDARD_SETTINGS`).

If you checked out a tag that predates those files (including `v4.1.10` and
`v4.1.10-platforms` at `754532d`), copy them from
[WINDOWS_HANDOFF_4.1.10.md](WINDOWS_HANDOFF_4.1.10.md) § “Patch the tree”
**before** `flutter build windows`.

`CMAKE_CXX_FLAGS` alone does **not** reliably reach plugin `.vcxproj` files.
That is why `Directory.Build.props` is required.

## 3. Checkout and pin-check

```bat
cd /d %EVOLVE_REPO%
git fetch origin --tags
git checkout v4.1.10-platforms
type pubspec.yaml | findstr /b version
```

`version:` must match the release you are freezing (4.1.10+176 for the 4.1.10
platform set). Then:

```bat
type assets\config\perc_network.json
type assets\assets\config\perc_network.json
```

Both must contain `135.181.152.10.sslip.io/perc` and must **not** use
`onrender.com` as `rendezvousUrl`.

```bat
pwsh -File scripts\doctor.ps1
pwsh -File scripts\doctor_windows_signing.ps1
```

Signing doctor exiting non-zero is expected until a PFX / store / SignPath
backend is configured. Build can still proceed with `-SkipCodeSign` for a
dev PE; **do not publish that PE as the signed release**.

## 4. Build the PE + Inno installer

From the repo root, elevated-not-required (installer uses
`PrivilegesRequired=lowest`):

```bat
cd /d %EVOLVE_REPO%
flutter pub get
pwsh -File scripts\build_windows_installer.ps1 -Version 4.1.10 -Build 176
```

Omit `-Version` / `-Build` to read them from `pubspec.yaml`.

That script:

1. Runs `scripts\build.ps1 windows` → `flutter build windows --release`
2. Signs PE files in `build\windows\x64\runner\Release` unless `-SkipCodeSign`
3. Runs Inno `ISCC.exe` on `installer\windows\evolve.iss`
4. Copies `evolve-v{ver}-windows-x64-setup.exe` to `build\downloads\v{ver}\`
5. Writes `.sha256` / `.sha512` sidecars

**Portable zip is extra** (the installer script does not create it):

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

### Expected tree after a good build

```
build\windows\x64\runner\Release\
  evolve.exe
  flutter_windows.dll
  data\app.so
  data\icudtl.dat
  data\flutter_assets\
  *_plugin.dll
  dartjni.dll
  Webview2Loader.dll

build\installer\windows\
  evolve-v{ver}-windows-x64-setup.exe

build\downloads\v{ver}\
  evolve-v{ver}-windows-x64-setup.exe
  evolve-v{ver}-windows-x64-setup.exe.sha256
  evolve-v{ver}-windows-x64.zip
  evolve-v{ver}-windows-x64.zip.sha256
```

`evolve.exe` is a small Flutter runner (tens of KB). The app is `data\app.so`
plus `flutter_windows.dll` (~20 MB). A 60 KB lone `.exe` with no `data\` is
**not** a shippable package.

Quick PE check:

```powershell
$bytes = [IO.File]::ReadAllBytes('build\windows\x64\runner\Release\evolve.exe')[0..1]
[Text.Encoding]::ASCII.GetString($bytes)   # must be MZ
```

## 5. Authenticode (required for a signed release)

Unsigned zip/setup is what GitHub currently has for 4.1.10. A SmartScreen /
“Windows protected your PC” warning is expected until this section is done.

### 5a. PFX (recommended)

```bat
pwsh -File scripts\setup_pfx_signing.ps1 -PfxPath C:\path\to\ov.pfx -PfxPassword <password>
pwsh -File scripts\finish_windows_signing.ps1 -Version 4.1.10
pwsh -File scripts\verify_windows_signatures.ps1
```

`setup_pfx_signing.ps1` writes `code_sign.local.env` (gitignored). Never commit
the PFX or that env file.

### 5b. Certificate store

Install the OV/EV cert in **Current User\Personal**, then set
`CODE_SIGN_MODE=store` in `code_sign.local.env`. Re-run
`finish_windows_signing.ps1`.

### 5c. SignPath Foundation (CI, not local `signtool`)

See [../.signpath/SETUP.txt](../.signpath/SETUP.txt). After approval, set
repo secrets/vars and `SIGNPATH_ENABLED=true`, then run the **SignPath Windows
Release** workflow.

**Known bug (still on `origin`):** the workflow step “Build unsigned Windows
installer” replaces `PATH` with Machine+User only and drops
`flutter-action`’s bin, so `flutter pub get` fails with “flutter is not
recognized”. The OAuth `gh` app used on the Mac cannot push
`.github/workflows/*.yml` (needs the `workflow` scope).

On the Windows machine, with a PAT that includes **`workflow`**, replace that
step’s first PATH line with:

```powershell
$flutterBin = if ($env:FLUTTER_ROOT) { Join-Path $env:FLUTTER_ROOT 'bin' } else { $null }
$machine = [System.Environment]::GetEnvironmentVariable('Path','Machine')
$user = [System.Environment]::GetEnvironmentVariable('Path','User')
$env:Path = (@($flutterBin, $env:Path, $machine, $user) | Where-Object { $_ }) -join ';'
```

Commit + push that workflow file, then `gh workflow run "SignPath Windows Release"`.

Until SignPath is approved **and** that PATH line is fixed, use 5a/5b locally.

## 6. Smoke on the build PC

1. Unzip the portable zip into a clean folder (or run the setup.exe).
2. Launch `evolve.exe`. Version badge must match `4.1.10` / build `176`.
3. Perccent wallet → force sync → height **> 0** (Helsinki tip).
4. Confirm rendezvous is Helsinki sslip, not Render.
5. If you signed: right-click `evolve.exe` → Properties → Digital Signatures
   must list the OV/EV publisher. `verify_windows_signatures.ps1` must exit 0.

## 7. Publish

GitHub **immutable releases** refuse new assets after publish (`HTTP 422`).
`v4.1.10` and `v4.1.10-platforms` are already immutable.

```bat
gh release create v4.1.10-windows ^
  --repo rgsneddon/evolve ^
  --title "Evolve 4.1.10 — Windows signed installer" ^
  --notes "Signed Inno setup + portable zip. Same 4.1.10+176 tree as v4.1.10-platforms." ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64-setup.exe ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64-setup.exe.sha256 ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64.zip ^
  build\downloads\v4.1.10\evolve-v4.1.10-windows-x64.zip.sha256
```

Optional gh-pages index:

```bat
pwsh -File scripts\deploy_downloads.ps1 -Version 4.1.10
```

## 8. What this machine cannot do

| Task | Where |
|---|---|
| `Evolve.app` / notarize | Mac — [MAC_BUILDS.md](MAC_BUILDS.md) |
| iOS IPA | Mac + Xcode |
| Linux tarball / Arch `.pkg.tar.zst` | Linux (Helsinki or `ubuntu-latest`) — `scripts/package_linux_release.sh` |
| Android APK | Any host with the Android SDK (already shipped for 4.1.10) |

## 9. Related files

| Path | Role |
|---|---|
| `scripts/build.ps1` | `flutter build windows` |
| `scripts/build_windows_installer.ps1` | PE + Inno + checksums |
| `scripts/finish_windows_signing.ps1` | sign + verify + restage |
| `scripts/doctor_windows_signing.ps1` | readiness JSON |
| `scripts/verify_windows_signatures.ps1` | Authenticode check |
| `installer/windows/evolve.iss` | Inno script |
| `installer/windows/README.txt` | short installer notes |
| `.signpath/SETUP.txt` | SignPath after approval |
| `Directory.Build.props` | MSVC 14.51+ plugin compile |
| `windows/CMakeLists.txt` | same define for CMake targets |
| `scripts/ci/evolve-desktop-linux-windows.yml` | proposed GHA (not under `.github/workflows/`) |
