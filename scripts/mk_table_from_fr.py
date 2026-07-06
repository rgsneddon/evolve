#!/usr/bin/env python3
"""Generate language tables from French base + per-language replacement rules."""
from __future__ import annotations

import re
from pathlib import Path

from wallet_ui_translate import _fr

SCRIPTS = Path(__file__).resolve().parent


def apply_rules(text: str, rules: list[tuple[str, str]]) -> str:
    out = text
    for src, dst in rules:
        out = out.replace(src, dst)
    return out


def emit(code: str, table: dict[str, str]) -> None:
    path = SCRIPTS / f"wallet_table_{code}.py"
    lines = [
        f'"""Wallet UI — {code}."""',
        "from __future__ import annotations",
        "",
        f"WALLET_{code.upper()} = " + "{",
    ]
    for key in sorted(table):
        val = table[key].replace("\\", "\\\\").replace("'", "\\'")
        lines.append(f"    '{key}': '{val}',")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    print(path.name, len(table))


# German: professional replacements on FR base where FR mirrors EN structure.
DE_RULES: list[tuple[str, str]] = [
    ("Entrer dans Evolve", "Evolve betreten"),
    ("Préparation du portefeuille", "Wallet wird vorbereitet"),
    ("Connecté en tant que", "Angemeldet als"),
    ("Recherche de mises à jour", "Suche nach Updates"),
    ("Vous avez la dernière version", "Sie haben die neueste Version"),
    ("Mise à jour disponible", "Update verfügbar"),
    ("Obtenir la mise à jour", "Update holen"),
    ("Adresse copiée", "Adresse kopiert"),
    ("Votre adresse Perccent", "Ihre Perccent-Adresse"),
    ("Créez d'abord votre portefeuille", "Erstellen Sie zuerst Ihre Wallet"),
    ("Retour à la connexion", "Zurück zur Anmeldung"),
    ("Solde disponible", "Verfügbares Guthaben"),
    ("Hauteur de bloc", "Blockhöhe"),
    ("C'est parti", "Los geht's"),
    ("Blockchain lancée", "Blockchain gestartet"),
    ("PERC brûlés", "Verbrannte PERC"),
    ("Autoriser la caméra", "Kamera erlauben"),
    ("Pas maintenant", "Nicht jetzt"),
    ("Ouvrir les réglages", "Einstellungen öffnen"),
    ("Choisir un nom d'utilisateur", "Benutzernamen wählen"),
    ("Copier l'adresse", "Adresse kopieren"),
    ("Créer un mot de passe", "Passwort erstellen"),
    ("Envoyer / Recevoir", "Senden / Empfangen"),
    ("Chaîne principale", "Main Chain"),
    ("Détails chaîne et réseau", "Chain- & Netzwerkdetails"),
    ("Blockchain évolutive", "Evolutionäre Blockchain"),
    ("Bloc actuel", "Aktueller Block"),
    ("Transactions", "Transaktionen"),
    ("l'explorateur blockchain", "den Blockchain-Explorer"),
    ("Déclenché par", "Ausgelöst von"),
    ("Récompense de base", "Basisbelohnung"),
    ("Total crédité", "Gesamt gutgeschrieben"),
    ("Connexion Evolve Wallet", "Evolve Wallet-Anmeldung"),
    ("Se déconnecter", "Abmelden"),
    ("Ouverture du portefeuille", "Wallet wird geöffnet"),
    ("Réessayer", "Erneut versuchen"),
    ("Mot de passe", "Passwort"),
    ("Confirmer le mot de passe", "Passwort bestätigen"),
    ("Recevoir", "Empfangen"),
    ("Envoyer", "Senden"),
    ("Créer un compte", "Konto erstellen"),
    ("Créer votre portefeuille", "Wallet erstellen"),
    ("Se connecter", "Anmelden"),
    ("Synchroniser le portefeuille", "Wallet synchronisieren"),
    ("Synchronisation", "Synchronisierung"),
    ("Nom d'utilisateur", "Benutzername"),
    ("Abstention", "Enthaltung"),
    ("Contre", "Dagegen"),
    ("Pour", "Dafür"),
    ("Vote", "Abstimmung"),
    ("Question posée", "Gestellte Frage"),
    ("Probabilité %", "Wahrscheinlichkeit %"),
    ("Score de cohésion sociale", "Soziale-Kohäsions-Score"),
]

# Load hand-tuned DE overrides for strings that FR rules miss.
from wallet_table_de_overrides import DE_OVERRIDES  # noqa: E402


def build_de(fr: dict[str, str]) -> dict[str, str]:
    out = {}
    for k, v in fr.items():
        out[k] = DE_OVERRIDES.get(k) or apply_rules(v, DE_RULES)
    out.update(DE_OVERRIDES)
    return out


if __name__ == "__main__":
    fr = _fr()
    emit("de", build_de(fr))