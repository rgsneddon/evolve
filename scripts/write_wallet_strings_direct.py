#!/usr/bin/env python3
"""Write lib/l10n/wallet_strings.dart directly (no JSON intermediate)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

from build_wallet_translations_data import PROVIDER
from wallet_ui_translate import ES_SUPPLEMENT, _fr

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
OUTPUT = ROOT / "lib/l10n/wallet_strings.dart"


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


def dart_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def format_map(name: str, data: dict[str, str]) -> str:
    lines = [f"const {name} = <String, String>{{"]
    for key in sorted(data):
        val = dart_escape(data[key])
        if len(val) > 72 and " " in val:
            lines.append(f"  '{key}':")
            lines.append(f"      '{val}',")
        else:
            lines.append(f"  '{key}': '{val}',")
    lines.append("};")
    return "\n".join(lines)


def es_supplement_keys(en: dict[str, str], es_effective: dict[str, str]) -> list[str]:
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
    keys: list[str] = []
    for key in sorted(en):
        if es_effective.get(key, en[key]) == en[key] and (
            any(key.startswith(p) for p in focus_prefixes)
            or any(s in key for s in ("status", "sync", "login", "send", "receive"))
        ):
            keys.append(key)
    return keys


def load_wallets(en: dict[str, str]) -> dict[str, dict[str, str]]:
    from wallet_all_lang_tables import TABLES

    out: dict[str, dict[str, str]] = {}
    for code in ("fr", "de", "pt", "ar", "zh", "hi", "ja"):
        table = TABLES[code]
        missing = [k for k in en if k not in table]
        if missing:
            print(f"ERROR {code} missing {len(missing)}: {missing[:3]}", file=sys.stderr)
            sys.exit(1)
        out[code] = {k: table[k] for k in sorted(en)}
    return out


def main() -> None:
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    en = parse_wallet_entries(extract_block(content, "_en"))
    es_raw = parse_wallet_entries(extract_block(content, "_es"))
    es_effective = dict(en)
    es_effective.update(es_raw)

    wallets = load_wallets(en)
    wallets["fr"] = _fr()

    supplement_keys = es_supplement_keys(en, es_effective)
    wallet_strings_es = {
        k: ES_SUPPLEMENT.get(k, wallets.get("es", {}).get(k, en[k]))
        for k in supplement_keys
    }
    # ES supplement only — not full es map
    wallet_strings_es = {k: ES_SUPPLEMENT[k] for k in supplement_keys if k in ES_SUPPLEMENT}
    for k in supplement_keys:
        if k not in wallet_strings_es:
            wallet_strings_es[k] = ES_SUPPLEMENT.get(k, en[k])

    parts = [
        "/// Wallet, splash, ward, and provider UI strings (supplemental l10n).",
        "/// English UI strings remain in app_localizations.dart _en block.",
        "",
        "// --- Spanish supplement (keys still English in _es) ---",
        format_map("walletStringsEs", wallet_strings_es),
        "",
    ]

    for dart_suffix, code in [
        ("Fr", "fr"),
        ("De", "de"),
        ("Pt", "pt"),
        ("Ar", "ar"),
        ("Zh", "zh"),
        ("Hi", "hi"),
        ("Ja", "ja"),
    ]:
        parts.append(f"// --- {code.upper()} full wallet/splash/ward ---")
        parts.append(format_map(f"walletStrings{dart_suffix}", wallets[code]))
        parts.append("")

    parts.append("// --- Provider status/error messages (all languages) ---")
    for dart_suffix, code in [
        ("En", "en"),
        ("Es", "es"),
        ("Fr", "fr"),
        ("De", "de"),
        ("Pt", "pt"),
        ("Ar", "ar"),
        ("Zh", "zh"),
        ("Hi", "hi"),
        ("Ja", "ja"),
    ]:
        parts.append(format_map(f"walletStringsProvider{dart_suffix}", PROVIDER[code]))
        parts.append("")

    OUTPUT.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT}")
    print(f"walletStringsEs: {len(wallet_strings_es)} keys")
    for dart_suffix, code in [
        ("Fr", "fr"),
        ("De", "de"),
        ("Pt", "pt"),
        ("Ar", "ar"),
        ("Zh", "zh"),
        ("Hi", "hi"),
        ("Ja", "ja"),
    ]:
        print(f"walletStrings{dart_suffix}: {len(wallets[code])} keys")
    for dart_suffix, code in [
        ("En", "en"),
        ("Es", "es"),
        ("Fr", "fr"),
        ("De", "de"),
        ("Pt", "pt"),
        ("Ar", "ar"),
        ("Zh", "zh"),
        ("Hi", "hi"),
        ("Ja", "ja"),
    ]:
        print(f"walletStringsProvider{dart_suffix}: {len(PROVIDER[code])} keys")


if __name__ == "__main__":
    main()