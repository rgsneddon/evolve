#!/usr/bin/env python3
"""Assemble wallet_translations_data.json from hand-crafted + generated language modules."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from build_wallet_translations_data import PROVIDER
from wallet_ui_translate import ES_SUPPLEMENT, _fr

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
OUT = Path(__file__).resolve().parent / "wallet_translations_data.json"


def extract_block(content: str, name: str) -> str:
    m = re.search(rf"final {name} = \{{(.*?)(?=final _\w+ =|\Z)", content, re.S)
    return m.group(1) if m else ""


def parse_wallet_entries(block: str) -> dict[str, str]:
    pattern = re.compile(
        r"'((?:wallet|splash|ward)_[^']+)':\s*"
        r"(?:'((?:\\'|[^'])*)'|\n\s*'((?:\\'|[^'])*)')",
        re.M,
    )
    entries: dict[str, str] = {}
    for match in pattern.finditer(block):
        key = match.group(1)
        val = (match.group(2) or match.group(3) or "").replace("\\'", "'")
        entries[key] = val
    return entries


def load_lang_modules() -> dict[str, dict[str, str]]:
    from wallet_ui_translate import _ar, _de, _hi, _ja, _pt, _zh

    return {
        "fr": _fr(),
        "de": _de(),
        "pt": _pt(),
        "ar": _ar(),
        "zh": _zh(),
        "hi": _hi(),
        "ja": _ja(),
    }


def main() -> None:
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    en = parse_wallet_entries(extract_block(content, "_en"))
    wallets = load_lang_modules()
    for code, data in wallets.items():
        missing = [k for k in en if k not in data]
        extra = [k for k in data if k not in en]
        if missing:
            print(f"ERROR {code} missing {len(missing)} keys", file=sys.stderr)
            for k in missing[:5]:
                print(f"  - {k}", file=sys.stderr)
            sys.exit(1)
        if extra:
            print(f"WARN {code} has {len(extra)} extra keys", file=sys.stderr)

    payload = {
        "provider": PROVIDER,
        "wallets": wallets,
        "es_supplement": ES_SUPPLEMENT,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()