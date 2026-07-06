#!/usr/bin/env python3
"""Translate checkpoint entries that still match English (except allowlist)."""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

from finalize_wallet_strings import GOOGLE, protect, restore

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
CHECKPOINT = Path(__file__).resolve().parent / "checkpoints"

SKIP_KEYS = {
    "wallet_send_amount_hint",  # numeric
    "wallet_cooldown_popup_ok",  # OK
}

SKIP_IF_VALUE = {
    "OK",
    "0.00000001",
}


def parse_en() -> dict[str, str]:
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    m = re.search(r"final _en = \{(.*?)final _es =", content, re.S)
    block = m.group(1)
    pat = re.compile(
        r"'((?:wallet|splash|ward)_[^']+)':\s*"
        r"(?:'((?:\\'|[^'])*)'|\n\s*'((?:\\'|[^'])*)')",
        re.M,
    )
    out: dict[str, str] = {}
    for match in pat.finditer(block):
        k = match.group(1)
        v = (match.group(2) or match.group(3) or "").replace("\\'", "'")
        out[k] = v
    return out


def needs_translation(key: str, en_val: str, cur_val: str) -> bool:
    if key in SKIP_KEYS or en_val in SKIP_IF_VALUE:
        return False
    if cur_val != en_val:
        return False
    # Keep proper nouns that are intentionally unchanged.
    if en_val in {"Evolve Wallet", "MAIN DAPP · v2.0"}:
        return False
    return True


def patch_lang(code: str, en: dict[str, str]) -> int:
    path = CHECKPOINT / f"{code}.json"
    table = json.loads(path.read_text(encoding="utf-8"))
    todo = [k for k in en if needs_translation(k, en[k], table.get(k, en[k]))]
    if not todo:
        return 0
    translator = GoogleTranslator(source="en", target=GOOGLE[code])
    updated = 0
    for key in todo:
        protected, ph = protect(en[key])
        for attempt in range(3):
            try:
                table[key] = restore(translator.translate(protected), ph)
                updated += 1
                break
            except Exception:
                time.sleep(1.0 * (attempt + 1))
        time.sleep(0.12)
        if updated % 20 == 0:
            path.write_text(json.dumps(table, ensure_ascii=False, indent=2), encoding="utf-8")
    path.write_text(json.dumps(table, ensure_ascii=False, indent=2), encoding="utf-8")
    return updated


def main() -> None:
    en = parse_en()
    for code in ("de", "pt", "ar", "zh", "hi", "ja"):
        n = patch_lang(code, en)
        print(f"{code}: patched {n}")


if __name__ == "__main__":
    main()