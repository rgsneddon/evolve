#!/usr/bin/env python3
import re
from pathlib import Path

content = (Path(__file__).resolve().parents[1] / "lib/l10n/wallet_strings.dart").read_text(
    encoding="utf-8"
)
maps = re.split(r"const (walletStrings\w+)", content)[1:]
for i in range(0, len(maps), 2):
    name = maps[i]
    section = maps[i + 1]
    keys = re.findall(r"'((?:wallet|splash|ward)_[^']+)':", section)
    print(f"{name}: {len(keys)}")