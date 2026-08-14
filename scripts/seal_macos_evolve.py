#!/usr/bin/env python3
"""Seal Evolve.app for Gatekeeper: Developer ID + hardened runtime + notary + staple.

Usage:
  python3 scripts/seal_macos_evolve.py --check-entitlements
  python3 scripts/seal_macos_evolve.py --app path/to/Evolve.app --out path/to/evolve-macos.zip
"""
from __future__ import annotations

import argparse
import os
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RELEASE_ENTITLEMENTS = REPO / "macos" / "Runner" / "Release.entitlements"
DEFAULT_IDENTITY = "Developer ID Application: Russell Sneddon (SFCBP95595)"
DEFAULT_PROFILE = "evolve-notary"
GET_TASK_ALLOW = "com.apple.security.get-task-allow"


def load_entitlements(path: Path) -> dict:
    raw = path.read_bytes()
    return plistlib.loads(raw)


def release_entitlements_forbid_debugger(path: Path = RELEASE_ENTITLEMENTS) -> dict:
    """Shipped Release entitlements must not allow a debugger (get-task-allow)."""
    ents = load_entitlements(path)
    if ents.get(GET_TASK_ALLOW) is True:
        raise SystemExit(f"{path} enables {GET_TASK_ALLOW}; Gatekeeper/notary will reject")
    if not ents.get("com.apple.security.network.client"):
        raise SystemExit(f"{path} missing network.client")
    return ents


def codesign_identity() -> str:
    return os.environ.get("EVOLVE_CODESIGN_IDENTITY", DEFAULT_IDENTITY)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=True, **kwargs)


def sign_bundle(app: Path, identity: str, entitlements: Path) -> None:
    release_entitlements_forbid_debugger(entitlements)
    if app.exists():
        run(["xattr", "-cr", str(app)])
    nested: list[Path] = []
    for root, dirs, files in os.walk(app):
        root_p = Path(root)
        for name in dirs:
            if name.endswith((".framework", ".bundle", ".app", ".xpc", ".appex")):
                nested.append(root_p / name)
        for name in files:
            if name.endswith(".dylib"):
                nested.append(root_p / name)
    nested.sort(key=lambda p: len(p.parts), reverse=True)
    seen: set[str] = set()
    for item in nested:
        key = str(item.resolve())
        if key in seen:
            continue
        seen.add(key)
        run(
            [
                "codesign",
                "--force",
                "--options",
                "runtime",
                "--timestamp",
                "--sign",
                identity,
                str(item),
            ]
        )
    run(
        [
            "codesign",
            "--force",
            "--options",
            "runtime",
            "--timestamp",
            "--entitlements",
            str(entitlements),
            "--sign",
            identity,
            str(app),
        ]
    )
    run(["codesign", "--verify", "--deep", "--strict", str(app)])


def zip_app(app: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()
    run(
        [
            "ditto",
            "-c",
            "-k",
            "--keepParent",
            "--sequesterRsrc",
            str(app),
            str(dest),
        ]
    )


def notarize_zip(zip_path: Path, profile: str) -> None:
    run(
        [
            "xcrun",
            "notarytool",
            "submit",
            str(zip_path),
            "--keychain-profile",
            profile,
            "--wait",
        ]
    )


def staple_app(app: Path) -> None:
    run(["xcrun", "stapler", "staple", str(app)])
    run(["xcrun", "stapler", "validate", str(app)])


def assess_twice(app: Path) -> None:
    for i in range(2):
        proc = subprocess.run(
            ["spctl", "--assess", "--type", "execute", "-vv", str(app)],
            check=False,
            capture_output=True,
            text=True,
        )
        blob = (proc.stdout or "") + (proc.stderr or "")
        print(f"spctl[{i + 1}]:", blob.strip(), flush=True)
        if proc.returncode != 0 or "accepted" not in blob:
            raise SystemExit(f"spctl assess {i + 1} failed: {blob}")


def seal(app: Path, out_zip: Path, identity: str, profile: str, entitlements: Path) -> None:
    sign_bundle(app, identity, entitlements)
    staging = out_zip.with_suffix(".notarize.zip")
    zip_app(app, staging)
    notarize_zip(staging, profile)
    staple_app(app)
    zip_app(app, out_zip)
    assess_twice(app)
    print(f"SEAL_OK {out_zip}", flush=True)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--check-entitlements", action="store_true")
    p.add_argument("--app", type=Path)
    p.add_argument("--out", type=Path)
    p.add_argument("--identity", default=codesign_identity())
    p.add_argument("--profile", default=os.environ.get("EVOLVE_NOTARY_PROFILE", DEFAULT_PROFILE))
    p.add_argument("--entitlements", type=Path, default=RELEASE_ENTITLEMENTS)
    args = p.parse_args(argv)
    release_entitlements_forbid_debugger(args.entitlements)
    if args.check_entitlements:
        print("entitlements_ok", args.entitlements)
        return 0
    if not args.app or not args.out:
        p.error("--app and --out are required unless --check-entitlements")
    seal(args.app.resolve(), args.out.resolve(), args.identity, args.profile, args.entitlements)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
