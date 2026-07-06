#!/usr/bin/env python3
"""Create wallet_lang_overrides.json with complete per-language tables."""
from __future__ import annotations

import json
import re
from pathlib import Path

from wallet_ui_translate import _fr

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
OUT = Path(__file__).resolve().parent / "wallet_lang_overrides.json"


def parse_en() -> dict[str, str]:
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    m = re.search(r"final _en = \{(.*?)final _es =", content, re.S)
    block = m.group(1) if m else ""
    pattern = re.compile(
        r"'((?:wallet|splash|ward)_[^']+)':\s*"
        r"(?:'((?:\\'|[^'])*)'|\n\s*'((?:\\'|[^'])*)')",
        re.M,
    )
    out: dict[str, str] = {}
    for match in pattern.finditer(block):
        key = match.group(1)
        val = (match.group(2) or match.group(3) or "").replace("\\'", "'")
        out[key] = val
    return out


# Hand-maintained full tables (imported from companion modules).
from wallet_table_de import WALLET_DE  # noqa: E402
from wallet_table_pt import WALLET_PT  # noqa: E402
from wallet_table_ar import WALLET_AR  # noqa: E402
from wallet_table_zh import WALLET_ZH  # noqa: E402
from wallet_table_hi import WALLET_HI  # noqa: E402
from wallet_table_ja import WALLET_JA  # noqa: E402


def main() -> None:
    en = parse_en()
    tables = {
        "de": WALLET_DE,
        "pt": WALLET_PT,
        "ar": WALLET_AR,
        "zh": WALLET_ZH,
        "hi": WALLET_HI,
        "ja": WALLET_JA,
    }
    for code, table in tables.items():
        if set(table) != set(en):
            missing = set(en) - set(table)
            extra = set(table) - set(en)
            raise SystemExit(f"{code}: missing={len(missing)} extra={len(extra)}")
    OUT.write_text(json.dumps(tables, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {OUT} — fr reference {len(_fr())} keys, en {len(en)} keys")


if __name__ == "__main__":
    main()