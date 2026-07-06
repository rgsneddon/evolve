#!/usr/bin/env python3
"""Auto-translate wallet UI strings (de, pt, ar, zh, hi, ja) with placeholder safety."""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

from build_wallet_translations_data import PROVIDER, provider_base
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


PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")
PROTECTED_TERMS = [
    "Perccent",
    "PERC",
    "Chronoflux",
    "Grok",
    "Beam",
    "Evolve",
    "ρt",
    "ω",
    "σ",
    "Iτ",
    "Jμ",
    "evolve_treasury",
    "rgsnedds",
    "rgsneddon",
    "MOD_*",
    "Community Ward",
    "SSUCF",
    "0.00000001",
    "283M",
    "100M",
    "10,000",
    "xx/100",
    "A2",
    "nμ",
    "vμ",
    "h(n)μν",
    "percpriv1",
]


def protect(text: str) -> tuple[str, list[str]]:
    tokens: list[str] = []

    def ph_sub(m: re.Match[str]) -> str:
        tokens.append(m.group(0))
        return f"⟦PH{len(tokens)-1}⟧"

    out = PLACEHOLDER_RE.sub(ph_sub, text)
    for i, term in enumerate(PROTECTED_TERMS):
        out = out.replace(term, f"⟦T{i}⟧")
    return out, tokens


def restore(text: str, placeholders: list[str]) -> str:
    out = text
    for i, term in enumerate(PROTECTED_TERMS):
        out = out.replace(f"⟦T{i}⟧", term)
        out = out.replace(f"⟦T{i}⟧".lower(), term)
    for i, ph in enumerate(placeholders):
        out = out.replace(f"⟦PH{i}⟧", ph)
        out = out.replace(f"⟦ph{i}⟧", ph)
    return out


def translate_batch(translator: GoogleTranslator, items: list[str]) -> list[str]:
    protected_items: list[str] = []
    placeholder_maps: list[list[str]] = []
    for text in items:
        protected, placeholders = protect(text)
        protected_items.append(protected)
        placeholder_maps.append(placeholders)

    translated_raw: list[str] = []
    chunk = 40
    for i in range(0, len(protected_items), chunk):
        batch = protected_items[i : i + chunk]
        for attempt in range(4):
            try:
                translated_raw.extend(translator.translate_batch(batch))
                break
            except Exception:
                time.sleep(1.5 * (attempt + 1))
        else:
            for text in batch:
                translated_raw.append(translator.translate(text))

    results: list[str] = []
    for raw, placeholders, original in zip(
        translated_raw, placeholder_maps, items, strict=True
    ):
        results.append(restore(raw or original, placeholders))
    return results


def build_lang(
    lang_code: str, en: dict[str, str], hand_crafted: dict[str, str] | None = None
) -> dict[str, str]:
    if hand_crafted and len(hand_crafted) >= len(en):
        return hand_crafted
    translator = GoogleTranslator(source="en", target=lang_code)
    keys = sorted(en)
    values = translate_batch(translator, [en[k] for k in keys])
    out = dict(zip(keys, values))
    if hand_crafted:
        out.update(hand_crafted)
    return out


def main() -> None:
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    en = parse_wallet_entries(extract_block(content, "_en"))

    wallets = {
        "fr": _fr(),
        "de": build_lang("de", en),
        "pt": build_lang("pt", en),
        "ar": build_lang("ar", en),
        "zh-CN": None,
        "hi": build_lang("hi", en),
        "ja": build_lang("ja", en),
    }
    # Chinese simplified
    wallets["zh"] = build_lang("zh-CN", en)

    payload = {
        "provider": PROVIDER,
        "wallets": wallets,
        "es_supplement": ES_SUPPLEMENT,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {OUT}")
    for code, data in wallets.items():
        print(f"  {code}: {len(data)} keys")


if __name__ == "__main__":
    main()