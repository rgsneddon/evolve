#!/usr/bin/env python3
"""Generate lib/l10n/wallet_strings.dart from English wallet keys."""
from __future__ import annotations

import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "lib/l10n/app_localizations.dart"
OUT = ROOT / "lib/l10n/wallet_strings.dart"

LANGS = {
    "Es": "es",
    "Fr": "fr",
    "De": "de",
    "Pt": "pt",
    "Ar": "ar",
    "Zh": "zh-CN",
    "Hi": "hi",
    "Ja": "ja",
}

EXTRA_EN = {
    "wallet_login_language_label": "Language",
    "wallet_password_mismatch": "Passwords do not match",
    "wallet_endpoint_label": "Endpoint: {endpoint}",
    "wallet_tx_microblock_seal": "Chronoflux microblock seal",
    "wallet_status_treasury_secured": "Treasury secured — awaiting seed treasury sign-in to launch chain",
    "wallet_status_account_created": "Account created",
    "wallet_status_signed_in": "Signed in as {user}",
    "wallet_err_sign_in_to_send": "Sign in to send {name}",
    "wallet_err_invalid_amount": "Enter a valid {symbol} amount (up to 8 decimal places)",
    "wallet_err_minimum_send": "Minimum send is {min} {symbol} (1 cent)",
    "wallet_err_insufficient_balance": "Insufficient balance — need {total} {symbol} ({amount} + {fee} network fee)",
    "wallet_err_recipient_not_found": "Recipient PERC address not found on the network — the owner must register and sign in once so the address is discoverable",
    "wallet_status_genesis_renewal": "Genesis block — treasury cycle {cycle} renewed (283M {symbol} {name})",
    "wallet_status_sent_instant": "Sent {amount} {symbol} to {dest} (network fee {fee} {symbol})",
    "wallet_status_sent_queued": "Sent {amount} {symbol} to {dest} (network fee {fee} {symbol}) — queued until they sign in on the network within {delay}, otherwise returns to your wallet",
    "wallet_status_treasury_empty": "Treasury empty — run another scenario later",
    "wallet_status_treasury_cap": "Treasury cap reached",
    "wallet_status_faucet_credited": "+{amount} {symbol}",
    "wallet_faucet_label_scs": "Social cohesion score analysis",
    "wallet_faucet_label_percent": "Percent chance analysis",
    "wallet_err_unknown_account": "Unknown account",
    "wallet_err_invalid_password": "Invalid password",
    "wallet_err_generic": "Something went wrong — try again",
    "wallet_err_address_empty": "Enter a recipient PERC address",
    "wallet_err_address_confidential": "Enter a valid confidential PERC address",
    "wallet_err_address_invalid": "Enter a valid PERC address",
    "wallet_receive_delay_12_months": "12 months",
    "wallet_receive_delay_months": "several months",
    "wallet_receive_delay_hours": "several hours",
    "wallet_receive_delay_seconds": "a short time",
}


def extract_en_wallet_keys() -> dict[str, str]:
    content = SRC.read_text(encoding="utf-8")
    m = re.search(r"final _en = \{(.*?)final _es =", content, re.S)
    block = m.group(1)
    entries: dict[str, str] = {}
    for key, val in re.findall(
        r"'((?:wallet|splash|ward)_[^']+)':\s*(?:\n\s*)?'((?:\\'|[^'])*)'",
        block,
    ):
        entries[key] = val.replace("\\'", "'")
    entries.update(EXTRA_EN)
    return dict(sorted(entries.items()))


def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def translate_one(text: str, target: str) -> str:
    from deep_translator import GoogleTranslator

    protected: list[str] = []

    def protect(m: re.Match[str]) -> str:
        protected.append(m.group(0))
        return f"__PH{len(protected)-1}__"

    work = re.sub(r"\{[^}]+\}", protect, text)
    try:
        out = GoogleTranslator(source="en", target=target).translate(work)
    except Exception:
        out = work
    for i, token in enumerate(protected):
        out = out.replace(f"__PH{i}__", token)
    return out


def translate_language(keys: list[str], values: list[str], target: str) -> dict[str, str]:
    result: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=12) as pool:
        futures = {
            pool.submit(translate_one, val, target): key
            for key, val in zip(keys, values)
        }
        for fut in as_completed(futures):
            key = futures[fut]
            try:
                result[key] = fut.result()
            except Exception:
                result[key] = dict(zip(keys, values))[key]
    return result


def main() -> None:
    entries = extract_en_wallet_keys()
    keys = list(entries.keys())
    values = [entries[k] for k in keys]
    print(f"Translating {len(keys)} wallet keys x {len(LANGS)} languages...")

    lines = [
        "// GENERATED — wallet UI strings for non-English locales.",
        "// Run: python scripts/generate_wallet_strings.py",
        "",
    ]

    for suffix, code in LANGS.items():
        print(f"  {code}...")
        translated = translate_language(keys, values, code)
        lines.append(f"const walletStrings{suffix} = <String, String>{{")
        for key in keys:
            val = translated.get(key, entries[key])
            lines.append(f"  '{key}': '{dart_escape(val)}',")
        lines.append("};")
        lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()