#!/usr/bin/env python3
"""Seed wallet_manual_translations.py from EN + FR with language-specific transforms."""
from __future__ import annotations

import json
import re
from pathlib import Path

from wallet_ui_translate import _fr

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
OUT = Path(__file__).resolve().parent / "wallet_manual_translations.py"


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


# Full professional tables maintained per language.
from wallet_manual_de import DE  # noqa: E402
from wallet_manual_pt import PT  # noqa: E402
from wallet_manual_ar import AR  # noqa: E402
from wallet_manual_zh import ZH  # noqa: E402
from wallet_manual_hi import HI  # noqa: E402
from wallet_manual_ja import JA  # noqa: E402


def main() -> None:
    en = parse_en()
    fr = _fr()
    manual = {"de": DE, "pt": PT, "ar": AR, "zh": ZH, "hi": HI, "ja": JA}
    for code, table in manual.items():
        if set(table) != set(en):
            raise SystemExit(
                f"{code}: expected {len(en)} keys, got {len(table)} "
                f"missing {len(set(en)-set(table))}"
            )
    lines = [
        '"""Hand-maintained wallet translations (de, pt, ar, zh, hi, ja)."""',
        "from __future__ import annotations",
        "",
        f"MANUAL: dict[str, dict[str, str]] = {json.dumps(manual, ensure_ascii=False, indent=4)}",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()