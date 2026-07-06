#!/usr/bin/env python3
"""Compact per-key translations: (key, de, pt, ar, zh, hi, ja)."""
from __future__ import annotations

# Rows are filled by scripts/fill_wallet_rows.py from EN+FR seeds.
# Each value must preserve placeholders like {user}, {amount}, etc.

ROWS: list[tuple[str, str, str, str, str, str, str]] = []