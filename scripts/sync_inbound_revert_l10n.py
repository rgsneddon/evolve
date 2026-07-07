#!/usr/bin/env python3
"""Rewrite wallet_inbound_revert_* labels from walletInboundRevertWindow."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONSTANTS = ROOT / "lib" / "perc" / "perc_chain_constants.dart"
TARGETS = [
    ROOT / "lib" / "l10n" / "app_localizations.dart",
    ROOT / "lib" / "l10n" / "wallet_strings.dart",
    ROOT / "scripts" / "generate_wallet_strings.py",
    ROOT / "scripts" / "build_wallet_translations_data.py",
    ROOT / "scripts" / "wallet_ui_translate.py",
]

HOURS_RE = re.compile(
    r"static const Duration walletInboundRevertWindow = Duration\(hours: (\d+)\);"
)
DAYS_RE = re.compile(
    r"static const Duration walletInboundRevertWindow = Duration\(days: (\d+)\);"
)


def parse_window_label() -> tuple[str, str, str]:
    text = CONSTANTS.read_text(encoding="utf-8")
    hours = HOURS_RE.search(text)
    if hours:
        n = int(hours.group(1))
        if n == 1:
            return ("1 hour", "1 hour", "a short time")
        return (f"{n} hours", f"{n} hours", "a short time")
    days = DAYS_RE.search(text)
    if days:
        n = int(days.group(1))
        if n == 1:
            return ("1 day", "1 day", "a short time")
        return (f"{n} days", f"{n} days", "a short time")
    raise SystemExit("walletInboundRevertWindow not found in perc_chain_constants.dart")


def patch_file(path: Path, days_label: str, hours_label: str, seconds_label: str) -> None:
    text = path.read_text(encoding="utf-8")
    text = re.sub(
        r"(['\"]wallet_inbound_revert_days['\"]\s*:\s*['\"])([^'\"]*)(['\"])",
        rf"\g<1>{days_label}\g<3>",
        text,
    )
    text = re.sub(
        r"(['\"]wallet_inbound_revert_hours['\"]\s*:\s*['\"])([^'\"]*)(['\"])",
        rf"\g<1>{hours_label}\g<3>",
        text,
    )
    text = re.sub(
        r"(['\"]wallet_inbound_revert_seconds['\"]\s*:\s*['\"])([^'\"]*)(['\"])",
        rf"\g<1>{seconds_label}\g<3>",
        text,
    )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    days_label, hours_label, seconds_label = parse_window_label()
    for target in TARGETS:
        if target.exists():
            patch_file(target, days_label, hours_label, seconds_label)
            print(f"updated {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()