#!/usr/bin/env python3
import json
import time
from pathlib import Path

CHECKPOINT_DIR = Path(__file__).resolve().parent / "checkpoints"
LANGS = ("de", "pt", "ar", "zh", "hi", "ja")
TARGET = 300


def counts() -> dict[str, int]:
    out = {}
    for code in LANGS:
        path = CHECKPOINT_DIR / f"{code}.json"
        if path.exists():
            out[code] = len(json.loads(path.read_text(encoding="utf-8")))
        else:
            out[code] = 0
    return out


def main() -> None:
    for _ in range(120):
        c = counts()
        print(c, "done" if all(v >= TARGET for v in c.values()) else "")
        if all(v >= TARGET for v in c.values()):
            return
        time.sleep(30)
    raise SystemExit("timeout waiting for checkpoints")


if __name__ == "__main__":
    main()