#!/usr/bin/env python3
"""Apply hand fixes for common UI strings left in English."""
from __future__ import annotations

import json
from pathlib import Path

CHECKPOINT = Path(__file__).resolve().parent / "checkpoints"

FIXES: dict[str, dict[str, str]] = {
    "pt": {
        "wallet_sync_button": "Sincronizar carteira",
        "wallet_sync_syncing": "A sincronizar…",
        "wallet_opening_retry": "Tentar novamente",
        "wallet_sign_in": "Iniciar sessão",
        "wallet_logout": "Terminar sessão",
        "wallet_send": "Enviar",
        "wallet_receive": "Receber",
    },
    "zh": {
        "wallet_sync_button": "同步钱包",
        "wallet_sync_syncing": "同步中…",
        "wallet_sign_in": "登录",
        "wallet_logout": "退出登录",
        "wallet_send": "发送",
        "wallet_receive": "接收",
    },
    "hi": {
        "wallet_sync_button": "वॉलेट सिंक करें",
        "wallet_sync_syncing": "सिंक हो रहा है…",
        "wallet_sign_in": "साइन इन",
        "wallet_logout": "साइन आउट",
        "wallet_send": "भेजें",
        "wallet_receive": "प्राप्त करें",
    },
    "ja": {
        "wallet_sync_button": "ウォレットを同期",
        "wallet_sync_syncing": "同期中…",
        "wallet_sign_in": "サインイン",
        "wallet_logout": "サインアウト",
        "wallet_send": "送信",
        "wallet_receive": "受信",
    },
    "de": {
        "wallet_sync_syncing": "Synchronisiere…",
    },
}


def main() -> None:
    for code, fixes in FIXES.items():
        path = CHECKPOINT / f"{code}.json"
        table = json.loads(path.read_text(encoding="utf-8"))
        table.update(fixes)
        path.write_text(json.dumps(table, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"{code}: applied {len(fixes)} fixes")


if __name__ == "__main__":
    main()