#!/usr/bin/env python3
"""Emit wallet_langs_{de,pt,ar,zh,hi,ja}.py from embedded translation tables."""
from __future__ import annotations

import re
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
LOCALIZATIONS = SCRIPTS.parent / "lib/l10n/app_localizations.dart"


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


def emit_lang(code: str, table: dict[str, str], en: dict[str, str]) -> None:
    path = SCRIPTS / f"wallet_langs_{code}.py"
    lines = [
        f'"""Wallet UI strings — {code}."""',
        "from __future__ import annotations",
        "",
        f"WALLET_{code.upper()} = " + "{",
    ]
    for key in sorted(en):
        val = table.get(key)
        if val is None:
            raise KeyError(f"{code} missing {key}")
        esc = val.replace("\\", "\\\\").replace("'", "\\'")
        lines.append(f"    '{key}': '{esc}',")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {path} ({len(en)} keys)")


# Import translation tables from companion module (generated / maintained).
from wallet_translation_tables import TABLES  # noqa: E402


def main() -> None:
    en = parse_en()
    for code in ("de", "pt", "ar", "zh", "hi", "ja"):
        emit_lang(code, TABLES[code], en)


if __name__ == "__main__":
    main()