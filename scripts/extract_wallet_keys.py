#!/usr/bin/env python3
"""Extract wallet/splash/ward l10n keys from app_localizations.dart _en block."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"


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


def main() -> None:
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    en = parse_wallet_entries(extract_block(content, "_en"))
    es_raw = parse_wallet_entries(extract_block(content, "_es"))
    es_effective = dict(en)
    es_effective.update(es_raw)

    focus_prefixes = (
        "wallet_login",
        "wallet_send",
        "wallet_receive",
        "wallet_sync",
        "wallet_status",
        "splash_",
        "wallet_sign",
        "wallet_register",
        "wallet_password",
        "wallet_opening",
        "wallet_mesh",
        "wallet_session",
    )

    es_supplement: dict[str, str] = {}
    for key, en_val in sorted(en.items()):
        es_val = es_effective.get(key, en_val)
        if es_val == en_val and (
            any(key.startswith(p) for p in focus_prefixes)
            or any(s in key for s in ("status", "sync", "login", "send", "receive"))
        ):
            es_supplement[key] = en_val

    if "--json" in sys.argv:
        out = {
            "en": en,
            "es_supplement_keys": list(es_supplement.keys()),
            "es_supplement": es_supplement,
        }
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return

    print(f"Found {len(en)} wallet/splash/ward keys in _en")
    print(f"Spanish supplement candidates (still English): {len(es_supplement)}")

    if "--keys" in sys.argv:
        for k in sorted(en):
            print(k)
        return

    for k in sorted(en):
        print(f"{k}\t{en[k]}")


if __name__ == "__main__":
    main()