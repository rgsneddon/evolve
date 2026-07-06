#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
CHECKPOINT = Path(__file__).resolve().parent / "checkpoints"


def parse_en():
    content = LOCALIZATIONS.read_text(encoding="utf-8")
    m = re.search(r"final _en = \{(.*?)final _es =", content, re.S)
    block = m.group(1)
    pat = re.compile(
        r"'((?:wallet|splash|ward)_[^']+)':\s*"
        r"(?:'((?:\\'|[^'])*)'|\n\s*'((?:\\'|[^'])*)')",
        re.M,
    )
    out = {}
    for match in pat.finditer(block):
        k = match.group(1)
        v = (match.group(2) or match.group(3) or "").replace("\\'", "'")
        out[k] = v
    return out


def main():
    en = parse_en()
    for code in ("de", "pt", "ar", "zh", "hi", "ja"):
        table = json.loads((CHECKPOINT / f"{code}.json").read_text(encoding="utf-8"))
        same = [k for k, v in table.items() if v == en.get(k)]
        print(f"{code}: {len(same)} identical to EN")
        if same[:5]:
            print("  e.g.", same[:5])


if __name__ == "__main__":
    main()