#!/usr/bin/env python3
"""Complete partial checkpoints and write wallet_strings.dart."""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

from build_wallet_translations_data import PROVIDER
from wallet_ui_translate import ES_SUPPLEMENT, _fr

try:
    from deep_translator import GoogleTranslator
except ImportError:
    GoogleTranslator = None  # type: ignore

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
CHECKPOINT_DIR = Path(__file__).resolve().parent / "checkpoints"
OUTPUT = ROOT / "lib/l10n/wallet_strings.dart"

GOOGLE = {"de": "de", "pt": "pt", "ar": "ar", "zh": "zh-CN", "hi": "hi", "ja": "ja"}
PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")
KEEP = [
    "Perccent", "PERC", "Chronoflux", "Grok", "Beam", "Evolve",
    "ρt", "ω", "σ", "Iτ", "Jμ", "evolve_treasury", "rgsnedds",
    "rgsneddon", "Community Ward", "0.00000001", "283M", "100M", "xx/100",
]


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


def protect(text: str) -> tuple[str, list[str]]:
    tokens: list[str] = []

    def ph_sub(m: re.Match[str]) -> str:
        tokens.append(m.group(0))
        return f"⟦{len(tokens)-1}⟧"

    out = PLACEHOLDER_RE.sub(ph_sub, text)
    for i, term in enumerate(KEEP):
        out = out.replace(term, f"⟦K{i}⟧")
    return out, tokens


def restore(text: str, placeholders: list[str]) -> str:
    out = text or ""
    for i, term in enumerate(KEEP):
        out = out.replace(f"⟦K{i}⟧", term)
    for i, ph in enumerate(placeholders):
        out = out.replace(f"⟦{i}⟧", ph)
    return out


def translate_missing(code: str, en: dict[str, str], table: dict[str, str]) -> dict[str, str]:
    """Fill gaps from checkpoints; optional API translate when ALLOW_API=1."""
    import os

    missing = [k for k in en if k not in table]
    if not missing:
        return table
    if os.environ.get("ALLOW_API") == "1" and GoogleTranslator is not None:
        translator = GoogleTranslator(source="en", target=GOOGLE[code])
        for key in missing:
            protected, ph = protect(en[key])
            for attempt in range(3):
                try:
                    table[key] = restore(translator.translate(protected), ph)
                    break
                except Exception:
                    time.sleep(1.0 * (attempt + 1))
            else:
                table[key] = en[key]
            time.sleep(0.05)
        return table
    for k in missing:
        table[k] = en[k]
    return table


def load_lang(code: str, en: dict[str, str]) -> dict[str, str]:
    path = CHECKPOINT_DIR / f"{code}.json"
    table = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    table = translate_missing(code, en, table)
    # Prefer provider hand translations for overlapping keys when present.
    if code in PROVIDER:
        for k, v in PROVIDER[code].items():
            if k in en:
                table[k] = v
    path.write_text(json.dumps(table, ensure_ascii=False, indent=2), encoding="utf-8")
    return table


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
        "wallet_login", "wallet_send", "wallet_receive", "wallet_sync",
        "wallet_status", "splash_", "wallet_sign", "wallet_register",
        "wallet_password", "wallet_opening", "wallet_mesh", "wallet_session",
    )
    keys: list[str] = []
    for key in sorted(en):
        if es_effective.get(key, en[key]) == en[key] and (
            any(key.startswith(p) for p in focus_prefixes)
            or any(s in key for s in ("status", "sync", "login", "send", "receive"))
        ):
            keys.append(key)
    return keys


def main() -> None:
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    en = parse_wallet_entries(extract_block(content, "_en"))
    es_raw = parse_wallet_entries(extract_block(content, "_es"))
    es_effective = dict(en)
    es_effective.update(es_raw)

    wallets = {"fr": _fr()}
    for code in ("de", "pt", "ar", "zh", "hi", "ja"):
        wallets[code] = load_lang(code, en)
        if set(wallets[code]) != set(en):
            missing = sorted(set(en) - set(wallets[code]))
            print(f"ERROR {code} still missing {missing[:5]}", file=sys.stderr)
            sys.exit(1)

    supplement_keys = es_supplement_keys(en, es_effective)
    wallet_strings_es = {
        k: ES_SUPPLEMENT.get(k, en[k]) for k in supplement_keys if k in ES_SUPPLEMENT
    }
    for k in supplement_keys:
        if k not in wallet_strings_es:
            wallet_strings_es[k] = ES_SUPPLEMENT.get(k, en[k])

    parts = [
        "// Wallet, splash, ward, and provider UI strings (supplemental l10n).",
        "// English UI strings remain in app_localizations.dart _en block.",
        "",
        "// --- Spanish supplement (keys still English in _es) ---",
        format_map("walletStringsEs", wallet_strings_es),
        "",
    ]
    for dart_suffix, code in [
        ("Fr", "fr"), ("De", "de"), ("Pt", "pt"), ("Ar", "ar"),
        ("Zh", "zh"), ("Hi", "hi"), ("Ja", "ja"),
    ]:
        parts.append(f"// --- {code.upper()} full wallet/splash/ward ---")
        parts.append(format_map(f"walletStrings{dart_suffix}", wallets[code]))
        parts.append("")

    parts.append("// --- Provider status/error messages (all languages) ---")
    for dart_suffix, code in [
        ("En", "en"), ("Es", "es"), ("Fr", "fr"), ("De", "de"), ("Pt", "pt"),
        ("Ar", "ar"), ("Zh", "zh"), ("Hi", "hi"), ("Ja", "ja"),
    ]:
        parts.append(format_map(f"walletStringsProvider{dart_suffix}", PROVIDER[code]))
        parts.append("")

    OUTPUT.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT}")
    print(f"walletStringsEs: {len(wallet_strings_es)} keys")
    for dart_suffix, code in [
        ("Fr", "fr"), ("De", "de"), ("Pt", "pt"), ("Ar", "ar"),
        ("Zh", "zh"), ("Hi", "hi"), ("Ja", "ja"),
    ]:
        print(f"walletStrings{dart_suffix}: {len(wallets[code])} keys")
    for dart_suffix, code in [
        ("En", "en"), ("Es", "es"), ("Fr", "fr"), ("De", "de"), ("Pt", "pt"),
        ("Ar", "ar"), ("Zh", "zh"), ("Hi", "hi"), ("Ja", "ja"),
    ]:
        print(f"walletStringsProvider{dart_suffix}: {len(PROVIDER[code])} keys")


if __name__ == "__main__":
    main()