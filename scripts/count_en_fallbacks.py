#!/usr/bin/env python3
import json
import re
from pathlib import Path

LOCALIZATIONS = Path(__file__).resolve().parents[1] / "lib/l10n/app_localizations.dart"
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
        path = CHECKPOINT / f"{code}.json"
        table = json.loads(path.read_text(encoding="utf-8"))
        missing = [k for k in en if k not in table]
        print(f"{code}: checkpoint {len(table)}/{len(en)}, missing {len(missing)}")


if __name__ == "__main__":
    main()