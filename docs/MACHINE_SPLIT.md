# Two-machine Evolve release split

This is the machine-split record in force for GitHub-commit release bundles.

| Machine | Produces | Not this machine’s commit deliverable |
|---------|----------|----------------------------------------|
| **This Mac** | Android, macOS, and iOS | Windows, Linux, and Arch Linux |
| **Windows laptop** | Windows, Linux, and Arch Linux | Android, macOS, and iOS |

- this Mac → Android + macOS + iOS
- the Windows laptop → Windows + Linux + Arch Linux

Current release line is the pin in `pubspec.yaml` / `PercAppVersion.current` (today **4.1.12+179**). Mac-owned packages for that line belong in `build/downloads/v{version}/` with the installer-script basenames:

- `evolve-v{version}-android-setup.apk`
- `evolve-v{version}-macos-x64.zip`
- `evolve-v{version}-ios-setup.ipa`

Windows / Linux / Arch packages are laptop commit deliverables. They are not required on this Mac and must not block a Mac-side GitHub-commit check of the current bundle.

This Mac builds Android / macOS / iOS for the current line. Windows / Linux / Arch stay on the laptop.

GitHub-commit packages for this line attach to one tag, **`v{version}`** (today `v4.1.12`). This Mac uploads Android / macOS / iOS onto that tag; the laptop uploads Windows / Linux / Arch onto the same tag. Do not open a `v{version}-macos-ios-android` sibling. See [GITHUB_RELEASES.md](GITHUB_RELEASES.md).

See [MAC_BUILDS.md](MAC_BUILDS.md) (this Mac) and [WINDOWS_HANDOFF_4.1.9.md](WINDOWS_HANDOFF_4.1.9.md) (laptop PE history).
