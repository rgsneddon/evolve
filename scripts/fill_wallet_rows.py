#!/usr/bin/env python3
"""Populate wallet_row_translations_data.py from translation checkpoints."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
CHECKPOINT_DIR = Path(__file__).resolve().parent / "checkpoints"
OUT = Path(__file__).resolve().parent / "wallet_row_translations_data.py"


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


def load_lang(code: str) -> dict[str, str]:
    path = CHECKPOINT_DIR / f"{code}.json"
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    en = parse_en()
    langs = {code: load_lang(code) for code in ("de", "pt", "ar", "zh", "hi", "ja")}
    for code, table in langs.items():
        if set(table) != set(en):
            missing = sorted(set(en) - set(table))
            raise SystemExit(f"{code} incomplete ({len(table)}/{len(en)}), e.g. {missing[:3]}")

    lines = [
        '"""Auto-generated row data for wallet_all_lang_tables."""',
        "from __future__ import annotations",
        "",
        "ROWS: dict[str, dict[str, str]] = {",
    ]
    for key in sorted(en):
        lines.append(f"    '{key}': {{")
        for code in ("de", "pt", "ar", "zh", "hi", "ja"):
            val = langs[code][key].replace("\\", "\\\\").replace("'", "\\'")
            lines.append(f"        '{code}': '{val}',")
        lines.append("    },")
    lines.append("}")
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT} ({len(en)} keys)")


if __name__ == "__main__":
    main()