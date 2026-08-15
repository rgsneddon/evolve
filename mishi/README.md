# MISHI — desktop moderator GUI

Dark-only grey/black shell, high-contrast yellow text, CLI-window inputs.
Tabs: LOGIN · APPROVE · VOTES · **rpAI** · CHAIN.

No mobile targets. Do not add iOS/Android Mishi.

## Mac (this machine)

```bash
cd /Users/russellsneddon/evolve-apple
./mishi/launch_mishi
# or
flutter run -d macos -t lib/mishi_main.dart
# packaged app
./mishi/build_macos_app.sh
open build/mishi/Mishi.app
```

Credentials / setup strings are **exactly one file**: `~/Desktop/mishi_credentials.txt`. Extra `mishi_cred*.txt` copies (repo, build, tmp, numbered Desktop dupes) are deleted on launch.
MISHI writes that file on download / first launch. The LOGIN tab shows the
full path and can copy it. Icons and favicon are the Restore Privacy logo set.

## Windows

Build the Windows `.exe` **on the Windows machine** (`flutter build windows -t lib/mishi_main.dart`).
This Mac cannot produce a native Windows Mishi executable.

## rpAI tab

NED learns from every permitted Evolve wallet event (tab clicks, keystrokes,
votes, transfers) and every permitted Restore Privacy VPN event (connect,
heartbeat, hop). Non-permitted sources are rejected. The tab shows
best-in-class benchmark tracks (accuracy, coverage, calibration, latency)
plus the capability matrix.
