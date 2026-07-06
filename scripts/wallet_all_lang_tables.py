"""Aggregate wallet language tables for wallet_strings.dart generation."""
from __future__ import annotations

from wallet_row_translations_data import ROWS
from wallet_ui_translate import _fr

TABLES: dict[str, dict[str, str]] = {
    "fr": _fr(),
    "de": {k: v["de"] for k, v in ROWS.items()},
    "pt": {k: v["pt"] for k, v in ROWS.items()},
    "ar": {k: v["ar"] for k, v in ROWS.items()},
    "zh": {k: v["zh"] for k, v in ROWS.items()},
    "hi": {k: v["hi"] for k, v in ROWS.items()},
    "ja": {k: v["ja"] for k, v in ROWS.items()},
}