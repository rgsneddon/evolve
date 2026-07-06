#!/usr/bin/env python3
"""Build per-language translation tables from EN + hand-maintained overrides file."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = Path(__file__).resolve().parent
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
OVERRIDES = SCRIPTS / "wallet_lang_overrides.json"


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


def emit_lang_fn(code: str, table: dict[str, str], en: dict[str, str]) -> str:
    lines = [f"def _{code}() -> dict[str, str]:", "    return {"]
    for key in sorted(en):
        val = table[key].replace("\\", "\\\\").replace("'", "\\'")
        lines.append(f"        '{key}': '{val}',")
    lines.append("    }")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    en = parse_en()
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    chunks: list[str] = []
    for code in ("de", "pt", "ar", "zh", "hi", "ja"):
        merged = dict(en)
        merged.update(overrides[code])
        if len(merged) != len(en):
            missing = set(en) - set(overrides[code])
            raise SystemExit(f"{code} overrides missing {len(missing)} keys")
        chunks.append(emit_lang_fn(code, merged, en))
    out = SCRIPTS / "wallet_ui_langs_generated.py"
    out.write_text("\n".join(chunks), encoding="utf-8")
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()