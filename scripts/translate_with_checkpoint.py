#!/usr/bin/env python3
"""Translate EN wallet keys to target lang with checkpoint file (resumable)."""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
CHECKPOINT_DIR = Path(__file__).resolve().parent / "checkpoints"

PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")
KEEP = [
    "Perccent", "PERC", "Chronoflux", "Grok", "Beam", "Evolve",
    "ρt", "ω", "σ", "Iτ", "Jμ", "evolve_treasury", "rgsnedds",
    "rgsneddon", "Community Ward", "0.00000001", "283M", "100M",
    "xx/100", "A2", "nμ", "vμ", "h(n)μν",
]


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


def translate_lang(target: str, google_code: str) -> None:
    CHECKPOINT_DIR.mkdir(exist_ok=True)
    path = CHECKPOINT_DIR / f"{target}.json"
    en = parse_en()
    done = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    translator = GoogleTranslator(source="en", target=google_code)
    keys = sorted(en)
    for i, key in enumerate(keys):
        if key in done:
            continue
        protected, ph = protect(en[key])
        for attempt in range(5):
            try:
                translated = translator.translate(protected)
                done[key] = restore(translated, ph)
                break
            except Exception as exc:
                print(f"retry {key} ({attempt}): {exc}")
                time.sleep(2 * (attempt + 1))
        else:
            done[key] = en[key]
        path.write_text(json.dumps(done, ensure_ascii=False, indent=2), encoding="utf-8")
        if (i + 1) % 10 == 0:
            print(f"{target}: {i+1}/{len(keys)}")
        time.sleep(0.08)
    print(f"Done {target}: {len(done)} keys -> {path}")


def emit_manual_module() -> None:
    en = parse_en()
    manual: dict[str, dict[str, str]] = {}
    for code in ("de", "pt", "ar", "zh", "hi", "ja"):
        path = CHECKPOINT_DIR / f"{code}.json"
        if not path.exists():
            raise SystemExit(f"Missing checkpoint {path}")
        table = json.loads(path.read_text(encoding="utf-8"))
        if set(table) != set(en):
            raise SystemExit(f"{code} incomplete: {len(table)}/{len(en)}")
        manual[code] = table

    for code, table in manual.items():
        out = Path(__file__).resolve().parent / f"wallet_manual_{code}.py"
        lines = [
            f'"""Wallet translations — {code}."""',
            "from __future__ import annotations",
            "",
            f"{code.upper()} = " + "{",
        ]
        for key in sorted(table):
            val = table[key].replace("\\", "\\\\").replace("'", "\\'")
            lines.append(f"    '{key}': '{val}',")
        lines.append("}")
        lines.append("")
        out.write_text("\n".join(lines), encoding="utf-8")
        print(f"Wrote {out.name}")


def main() -> None:
    import sys

    if len(sys.argv) < 2:
        print("Usage: translate_with_checkpoint.py <de|pt|ar|zh|hi|ja|emit>")
        raise SystemExit(1)
    cmd = sys.argv[1]
    mapping = {
        "de": "de",
        "pt": "pt",
        "ar": "ar",
        "zh": "zh-CN",
        "hi": "hi",
        "ja": "ja",
    }
    if cmd == "emit":
        emit_manual_module()
        return
    if cmd not in mapping:
        raise SystemExit(f"Unknown lang {cmd}")
    translate_lang(cmd, mapping[cmd])


if __name__ == "__main__":
    main()