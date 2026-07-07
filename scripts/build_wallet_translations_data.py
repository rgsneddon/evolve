#!/usr/bin/env python3
"""Build wallet_translations_data.json — run generate_wallet_strings.py after this."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATIONS = ROOT / "lib/l10n/app_localizations.dart"
OUT = Path(__file__).resolve().parent / "wallet_translations_data.json"


def extract_block(content: str, name: str) -> str:
    m = re.search(rf"final {name} = \{{(.*?)(?=final _\w+ =|\Z)", content, re.S)
    return m.group(1) if m else ""


def parse_wallet_entries(block: str) -> dict[str, str]:
    pattern = re.compile(
        r"'((?:wallet|splash|ward)_[^']+)':\s*"
        r"(?:'((?:\\'|[^'])*)'|\n\s*'((?:\\'|[^'])*)')",
        re.M,
    )
    entries: dict[str, str] = {}
    for match in pattern.finditer(block):
        key = match.group(1)
        val = (match.group(2) or match.group(3) or "").replace("\\'", "'")
        entries[key] = val
    return entries


def provider_base() -> dict[str, str]:
    return {
        "wallet_status_treasury_secured": (
            "Treasury secured — awaiting seed treasury sign-in to launch chain"
        ),
        "wallet_status_account_created": "Account created",
        "wallet_status_signed_in": "Signed in as {user}",
        "wallet_err_sign_in_to_send": "Sign in to send {name}",
        "wallet_err_invalid_amount": (
            "Enter a valid {symbol} amount (up to 8 decimal places)"
        ),
        "wallet_err_minimum_send": (
            "Minimum send is {min} {symbol} (1 cent)"
        ),
        "wallet_err_insufficient_balance": (
            "Insufficient balance — need {total} {symbol} "
            "({amount} + {fee} network fee)"
        ),
        "wallet_err_recipient_not_found": (
            "Recipient PERC address not found on the network — the owner must "
            "register and sign in once so the address is discoverable"
        ),
        "wallet_status_genesis_renewal": (
            "Genesis block — treasury cycle {cycle} renewed "
            "(283M {symbol} {name})"
        ),
        "wallet_status_sent_instant": (
            "Sent {amount} {symbol} to {dest} "
            "(network fee {fee} {symbol})"
        ),
        "wallet_status_sent_queued": (
            "Sent {amount} {symbol} to {dest} "
            "(network fee {fee} {symbol}) — queued until they sign in on the "
            "network within {delay}, otherwise returns to your wallet"
        ),
        "wallet_status_treasury_empty": (
            "Treasury empty — run another scenario later"
        ),
        "wallet_status_treasury_cap": "Treasury cap reached",
        "wallet_err_unknown_account": "Unknown account",
        "wallet_err_invalid_password": "Invalid password",
        "wallet_err_generic": "Something went wrong — try again",
        "wallet_err_address_empty": "Enter a recipient PERC address",
        "wallet_err_address_confidential": "Enter a valid confidential PERC address",
        "wallet_err_address_invalid": "Enter a valid PERC address",
        "wallet_password_mismatch": "Passwords do not match",
        "wallet_endpoint_label": "Endpoint: {endpoint}",
        "wallet_tx_microblock_seal": "Chronoflux microblock seal",
        "wallet_login_language_label": "Language",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "Percent chance analysis",
        "wallet_faucet_label_scs": "Social cohesion score analysis",
    }


PROVIDER: dict[str, dict[str, str]] = {
    "en": provider_base(),
    "es": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "Tesorería asegurada — en espera del inicio de sesión de tesorería "
            "semilla para lanzar la cadena"
        ),
        "wallet_status_account_created": "Cuenta creada",
        "wallet_status_signed_in": "Sesión iniciada como {user}",
        "wallet_err_sign_in_to_send": "Inicie sesión para enviar {name}",
        "wallet_err_invalid_amount": (
            "Introduzca una cantidad válida de {symbol} (hasta 8 decimales)"
        ),
        "wallet_err_minimum_send": (
            "El envío mínimo es {min} {symbol} (1 cent)"
        ),
        "wallet_err_insufficient_balance": (
            "Saldo insuficiente — necesita {total} {symbol} "
            "({amount} + {fee} de comisión de red)"
        ),
        "wallet_err_recipient_not_found": (
            "Dirección PERC del destinatario no encontrada en la red — el "
            "propietario debe registrarse e iniciar sesión una vez para que "
            "la dirección sea localizable"
        ),
        "wallet_status_genesis_renewal": (
            "Bloque génesis — ciclo de tesorería {cycle} renovado "
            "(283M {symbol} {name})"
        ),
        "wallet_status_sent_instant": (
            "Enviado {amount} {symbol} a {dest} "
            "(comisión de red {fee} {symbol})"
        ),
        "wallet_status_sent_queued": (
            "Enviado {amount} {symbol} a {dest} "
            "(comisión de red {fee} {symbol}) — en cola hasta que inicien "
            "sesión en la red en {delay}; si no, vuelve a su monedero"
        ),
        "wallet_status_treasury_empty": (
            "Tesorería vacía — ejecute otro escenario más tarde"
        ),
        "wallet_status_treasury_cap": "Límite de tesorería alcanzado",
        "wallet_err_unknown_account": "Cuenta desconocida",
        "wallet_err_invalid_password": "Contraseña no válida",
        "wallet_err_generic": "Algo salió mal — inténtelo de nuevo",
        "wallet_err_address_empty": "Introduzca una dirección PERC del destinatario",
        "wallet_err_address_confidential": (
            "Introduzca una dirección PERC confidencial válida"
        ),
        "wallet_err_address_invalid": "Introduzca una dirección PERC válida",
        "wallet_password_mismatch": "Las contraseñas no coinciden",
        "wallet_endpoint_label": "Endpoint: {endpoint}",
        "wallet_tx_microblock_seal": "Sello de microbloque Chronoflux",
        "wallet_login_language_label": "Idioma",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "Análisis de probabilidad %",
        "wallet_faucet_label_scs": "Análisis de cohesión social",
    },
    "fr": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "Trésorerie sécurisée — en attente de la connexion trésorerie "
            "seed pour lancer la chaîne"
        ),
        "wallet_status_account_created": "Compte créé",
        "wallet_status_signed_in": "Connecté en tant que {user}",
        "wallet_err_sign_in_to_send": "Connectez-vous pour envoyer {name}",
        "wallet_err_invalid_amount": (
            "Saisissez un montant {symbol} valide (jusqu'à 8 décimales)"
        ),
        "wallet_err_minimum_send": (
            "Envoi minimum : {min} {symbol} (1 cent)"
        ),
        "wallet_err_insufficient_balance": (
            "Solde insuffisant — {total} {symbol} requis "
            "({amount} + {fee} de frais réseau)"
        ),
        "wallet_err_recipient_not_found": (
            "Adresse PERC du destinataire introuvable sur le réseau — le "
            "propriétaire doit s'inscrire et se connecter une fois pour que "
            "l'adresse soit détectable"
        ),
        "wallet_status_genesis_renewal": (
            "Bloc genèse — cycle trésorerie {cycle} renouvelé "
            "(283M {symbol} {name})"
        ),
        "wallet_status_sent_instant": (
            "Envoyé {amount} {symbol} à {dest} "
            "(frais réseau {fee} {symbol})"
        ),
        "wallet_status_sent_queued": (
            "Envoyé {amount} {symbol} à {dest} "
            "(frais réseau {fee} {symbol}) — en file jusqu'à connexion sur "
            "le réseau sous {delay}, sinon retour vers votre portefeuille"
        ),
        "wallet_status_treasury_empty": (
            "Trésorerie vide — relancez un scénario plus tard"
        ),
        "wallet_status_treasury_cap": "Plafond de trésorerie atteint",
        "wallet_err_unknown_account": "Compte inconnu",
        "wallet_err_invalid_password": "Mot de passe incorrect",
        "wallet_err_generic": "Une erreur s'est produite — réessayez",
        "wallet_err_address_empty": "Saisissez une adresse PERC du destinataire",
        "wallet_err_address_confidential": (
            "Saisissez une adresse PERC confidentielle valide"
        ),
        "wallet_err_address_invalid": "Saisissez une adresse PERC valide",
        "wallet_password_mismatch": "Les mots de passe ne correspondent pas",
        "wallet_endpoint_label": "Point de terminaison : {endpoint}",
        "wallet_tx_microblock_seal": "Scellement microbloc Chronoflux",
        "wallet_login_language_label": "Langue",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "Analyse de probabilité %",
        "wallet_faucet_label_scs": "Analyse de cohésion sociale",
    },
    "de": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "Treasury gesichert — warte auf Seed-Treasury-Anmeldung zum "
            "Start der Chain"
        ),
        "wallet_status_account_created": "Konto erstellt",
        "wallet_status_signed_in": "Angemeldet als {user}",
        "wallet_err_sign_in_to_send": "Melden Sie sich an, um {name} zu senden",
        "wallet_err_invalid_amount": (
            "Geben Sie einen gültigen {symbol}-Betrag ein (bis zu 8 Dezimalstellen)"
        ),
        "wallet_err_minimum_send": (
            "Mindestsendung: {min} {symbol} (1 Cent)"
        ),
        "wallet_err_insufficient_balance": (
            "Unzureichendes Guthaben — {total} {symbol} erforderlich "
            "({amount} + {fee} Netzwerkgebühr)"
        ),
        "wallet_err_recipient_not_found": (
            "PERC-Adresse des Empfängers im Netzwerk nicht gefunden — der "
            "Inhaber muss sich registrieren und einmal anmelden, damit die "
            "Adresse auffindbar ist"
        ),
        "wallet_status_genesis_renewal": (
            "Genesis-Block — Treasury-Zyklus {cycle} erneuert "
            "(283M {symbol} {name})"
        ),
        "wallet_status_sent_instant": (
            "{amount} {symbol} an {dest} gesendet "
            "(Netzwerkgebühr {fee} {symbol})"
        ),
        "wallet_status_sent_queued": (
            "{amount} {symbol} an {dest} gesendet "
            "(Netzwerkgebühr {fee} {symbol}) — in Warteschlange bis Anmeldung "
            "im Netzwerk innerhalb von {delay}, sonst Rückgabe an Ihre Wallet"
        ),
        "wallet_status_treasury_empty": (
            "Treasury leer — führen Sie später ein weiteres Szenario aus"
        ),
        "wallet_status_treasury_cap": "Treasury-Obergrenze erreicht",
        "wallet_err_unknown_account": "Unbekanntes Konto",
        "wallet_err_invalid_password": "Ungültiges Passwort",
        "wallet_err_generic": "Etwas ist schiefgelaufen — bitte erneut versuchen",
        "wallet_err_address_empty": "Geben Sie eine PERC-Empfängeradresse ein",
        "wallet_err_address_confidential": (
            "Geben Sie eine gültige vertrauliche PERC-Adresse ein"
        ),
        "wallet_err_address_invalid": "Geben Sie eine gültige PERC-Adresse ein",
        "wallet_password_mismatch": "Passwörter stimmen nicht überein",
        "wallet_endpoint_label": "Endpunkt: {endpoint}",
        "wallet_tx_microblock_seal": "Chronoflux-Mikroblock-Siegel",
        "wallet_login_language_label": "Sprache",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "Wahrscheinlichkeitsanalyse %",
        "wallet_faucet_label_scs": "Soziale-Kohäsionsanalyse",
    },
    "pt": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "Tesouraria protegida — aguardando login da tesouraria seed "
            "para lançar a cadeia"
        ),
        "wallet_status_account_created": "Conta criada",
        "wallet_status_signed_in": "Sessão iniciada como {user}",
        "wallet_err_sign_in_to_send": "Inicie sessão para enviar {name}",
        "wallet_err_invalid_amount": (
            "Introduza um montante {symbol} válido (até 8 casas decimais)"
        ),
        "wallet_err_minimum_send": (
            "Envio mínimo: {min} {symbol} (1 cent)"
        ),
        "wallet_err_insufficient_balance": (
            "Saldo insuficiente — necessita {total} {symbol} "
            "({amount} + {fee} de taxa de rede)"
        ),
        "wallet_err_recipient_not_found": (
            "Endereço PERC do destinatário não encontrado na rede — o "
            "titular deve registar-se e iniciar sessão uma vez para o "
            "endereço ser localizável"
        ),
        "wallet_status_genesis_renewal": (
            "Bloco génesis — ciclo da tesouraria {cycle} renovado "
            "(283M {symbol} {name})"
        ),
        "wallet_status_sent_instant": (
            "Enviado {amount} {symbol} para {dest} "
            "(taxa de rede {fee} {symbol})"
        ),
        "wallet_status_sent_queued": (
            "Enviado {amount} {symbol} para {dest} "
            "(taxa de rede {fee} {symbol}) — em fila até iniciarem sessão na "
            "rede em {delay}; caso contrário, devolve à sua carteira"
        ),
        "wallet_status_treasury_empty": (
            "Tesouraria vazia — execute outro cenário mais tarde"
        ),
        "wallet_status_treasury_cap": "Limite da tesouraria atingido",
        "wallet_err_unknown_account": "Conta desconhecida",
        "wallet_err_invalid_password": "Palavra-passe inválida",
        "wallet_err_generic": "Algo correu mal — tente novamente",
        "wallet_err_address_empty": "Introduza um endereço PERC do destinatário",
        "wallet_err_address_confidential": (
            "Introduza um endereço PERC confidencial válido"
        ),
        "wallet_err_address_invalid": "Introduza um endereço PERC válido",
        "wallet_password_mismatch": "As palavras-passe não coincidem",
        "wallet_endpoint_label": "Endpoint: {endpoint}",
        "wallet_tx_microblock_seal": "Selo de microbloco Chronoflux",
        "wallet_login_language_label": "Idioma",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "Análise de probabilidade %",
        "wallet_faucet_label_scs": "Análise de coesão social",
    },
    "ar": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "تم تأمين الخزينة — في انتظار تسجيل دخول خزينة البذرة لإطلاق السلسلة"
        ),
        "wallet_status_account_created": "تم إنشاء الحساب",
        "wallet_status_signed_in": "تم تسجيل الدخول باسم {user}",
        "wallet_err_sign_in_to_send": "سجّل الدخول لإرسال {name}",
        "wallet_err_invalid_amount": (
            "أدخل مبلغ {symbol} صالحًا (حتى 8 منازل عشرية)"
        ),
        "wallet_err_minimum_send": (
            "الحد الأدنى للإرسال: {min} {symbol} (سنت واحد)"
        ),
        "wallet_err_insufficient_balance": (
            "رصيد غير كافٍ — تحتاج {total} {symbol} "
            "({amount} + {fee} رسوم الشبكة)"
        ),
        "wallet_err_recipient_not_found": (
            "عنوان PERC للمستلم غير موجود على الشبكة — يجب على المالك التسجيل "
            "وتسجيل الدخول مرة واحدة ليصبح العنوان قابلاً للاكتشاف"
        ),
        "wallet_status_genesis_renewal": (
            "كتلة التكوين — تجديد دورة الخزينة {cycle} "
            "(283M {symbol} {name})"
        ),
        "wallet_status_sent_instant": (
            "تم إرسال {amount} {symbol} إلى {dest} "
            "(رسوم الشبكة {fee} {symbol})"
        ),
        "wallet_status_sent_queued": (
            "تم إرسال {amount} {symbol} إلى {dest} "
            "(رسوم الشبكة {fee} {symbol}) — في الانتظار حتى يسجلوا الدخول "
            "على الشبكة خلال {delay}، وإلا يعود إلى محفظتك"
        ),
        "wallet_status_treasury_empty": (
            "الخزينة فارغة — شغّل سيناريو آخر لاحقًا"
        ),
        "wallet_status_treasury_cap": "تم بلوغ حد الخزينة",
        "wallet_err_unknown_account": "حساب غير معروف",
        "wallet_err_invalid_password": "كلمة مرور غير صحيحة",
        "wallet_err_generic": "حدث خطأ — حاول مرة أخرى",
        "wallet_err_address_empty": "أدخل عنوان PERC للمستلم",
        "wallet_err_address_confidential": "أدخل عنوان PERC سريًا صالحًا",
        "wallet_err_address_invalid": "أدخل عنوان PERC صالحًا",
        "wallet_password_mismatch": "كلمتا المرور غير متطابقتين",
        "wallet_endpoint_label": "نقطة النهاية: {endpoint}",
        "wallet_tx_microblock_seal": "ختم microblock Chronoflux",
        "wallet_login_language_label": "اللغة",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "تحليل احتمال النسبة",
        "wallet_faucet_label_scs": "تحليل درجة التماسك الاجتماعي",
    },
    "zh": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "国库已保护 — 等待种子国库登录以启动链"
        ),
        "wallet_status_account_created": "账户已创建",
        "wallet_status_signed_in": "已以 {user} 登录",
        "wallet_err_sign_in_to_send": "请登录后再发送 {name}",
        "wallet_err_invalid_amount": (
            "请输入有效的 {symbol} 金额（最多 8 位小数）"
        ),
        "wallet_err_minimum_send": (
            "最低发送额为 {min} {symbol}（1 cent）"
        ),
        "wallet_err_insufficient_balance": (
            "余额不足 — 需要 {total} {symbol} "
            "（{amount} + {fee} 网络费）"
        ),
        "wallet_err_recipient_not_found": (
            "网络上未找到收件人 PERC 地址 — 所有者须注册并登录一次，"
            "地址方可被发现"
        ),
        "wallet_status_genesis_renewal": (
            "创世区块 — 国库周期 {cycle} 已续期 "
            "（283M {symbol} {name}）"
        ),
        "wallet_status_sent_instant": (
            "已向 {dest} 发送 {amount} {symbol} "
            "（网络费 {fee} {symbol}）"
        ),
        "wallet_status_sent_queued": (
            "已向 {dest} 发送 {amount} {symbol} "
            "（网络费 {fee} {symbol}）— 排队等待对方在 {delay} 内登录网络，"
            "否则退回您的钱包"
        ),
        "wallet_status_treasury_empty": (
            "国库为空 — 请稍后运行其他情景"
        ),
        "wallet_status_treasury_cap": "已达国库上限",
        "wallet_err_unknown_account": "未知账户",
        "wallet_err_invalid_password": "密码无效",
        "wallet_err_generic": "出现问题 — 请重试",
        "wallet_err_address_empty": "请输入收件人 PERC 地址",
        "wallet_err_address_confidential": "请输入有效的保密 PERC 地址",
        "wallet_err_address_invalid": "请输入有效的 PERC 地址",
        "wallet_password_mismatch": "两次密码不一致",
        "wallet_endpoint_label": "端点：{endpoint}",
        "wallet_tx_microblock_seal": "Chronoflux 微块封印",
        "wallet_login_language_label": "语言",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "概率百分比分析",
        "wallet_faucet_label_scs": "社会凝聚力分析",
    },
    "hi": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "कोष सुरक्षित — चेन लॉन्च के लिए सीड ट्रेज़री साइन-इन की प्रतीक्षा"
        ),
        "wallet_status_account_created": "खाता बनाया गया",
        "wallet_status_signed_in": "{user} के रूप में साइन इन",
        "wallet_err_sign_in_to_send": "{name} भेजने के लिए साइन इन करें",
        "wallet_err_invalid_amount": (
            "मान्य {symbol} राशि दर्ज करें (8 दशमलव तक)"
        ),
        "wallet_err_minimum_send": (
            "न्यूनतम भेजना: {min} {symbol} (1 cent)"
        ),
        "wallet_err_insufficient_balance": (
            "अपर्याप्त शेष — {total} {symbol} आवश्यक "
            "({amount} + {fee} नेटवर्क शुल्क)"
        ),
        "wallet_err_recipient_not_found": (
            "नेटवर्क पर प्राप्तकर्ता PERC पता नहीं मिला — मालिक को एक बार "
            "पंजीकरण और साइन इन करना होगा ताकि पता खोजा जा सके"
        ),
        "wallet_status_genesis_renewal": (
            "जेनेसिस ब्लॉक — ट्रेज़री चक्र {cycle} नवीनीकृत "
            "(283M {symbol} {name})"
        ),
        "wallet_status_sent_instant": (
            "{dest} को {amount} {symbol} भेजा गया "
            "(नेटवर्क शुल्क {fee} {symbol})"
        ),
        "wallet_status_sent_queued": (
            "{dest} को {amount} {symbol} भेजा गया "
            "(नेटवर्क शुल्क {fee} {symbol}) — {delay} के भीतर नेटवर्क पर "
            "साइन इन होने तक कतार में, अन्यथा आपके वॉलेट में वापस"
        ),
        "wallet_status_treasury_empty": (
            "कोष खाली — बाद में दूसरा परिदृश्य चलाएँ"
        ),
        "wallet_status_treasury_cap": "कोष सीमा पूरी",
        "wallet_err_unknown_account": "अज्ञात खाता",
        "wallet_err_invalid_password": "अमान्य पासवर्ड",
        "wallet_err_generic": "कुछ गलत हुआ — पुनः प्रयास करें",
        "wallet_err_address_empty": "प्राप्तकर्ता PERC पता दर्ज करें",
        "wallet_err_address_confidential": "मान्य गोपनीय PERC पता दर्ज करें",
        "wallet_err_address_invalid": "मान्य PERC पता दर्ज करें",
        "wallet_password_mismatch": "पासवर्ड मेल नहीं खाते",
        "wallet_endpoint_label": "एंडपॉइंट: {endpoint}",
        "wallet_tx_microblock_seal": "Chronoflux माइक्रोब्लॉक सील",
        "wallet_login_language_label": "भाषा",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "確率パーセント分析",
        "wallet_faucet_label_scs": "社会結束スコア分析",
    },
    "ja": {
        **provider_base(),
        "wallet_status_treasury_secured": (
            "トレジャリーを保護しました — チェーン起動のためシード・トレジャリーの"
            "サインインを待機中"
        ),
        "wallet_status_account_created": "アカウントを作成しました",
        "wallet_status_signed_in": "{user} としてサインイン",
        "wallet_err_sign_in_to_send": "{name} を送るにはサインインしてください",
        "wallet_err_invalid_amount": (
            "有効な {symbol} 金額を入力してください（小数点以下8桁まで）"
        ),
        "wallet_err_minimum_send": (
            "最小送信額は {min} {symbol}（1 cent）です"
        ),
        "wallet_err_insufficient_balance": (
            "残高不足 — {total} {symbol} が必要です "
            "（{amount} + ネットワーク手数料 {fee}）"
        ),
        "wallet_err_recipient_not_found": (
            "ネットワーク上に受取人の PERC アドレスが見つかりません — "
            "所有者が一度登録してサインインする必要があります"
        ),
        "wallet_status_genesis_renewal": (
            "ジェネシスブロック — トレジャリーサイクル {cycle} を更新 "
            "（283M {symbol} {name}）"
        ),
        "wallet_status_sent_instant": (
            "{dest} へ {amount} {symbol} を送信 "
            "（ネットワーク手数料 {fee} {symbol}）"
        ),
        "wallet_status_sent_queued": (
            "{dest} へ {amount} {symbol} を送信 "
            "（ネットワーク手数料 {fee} {symbol}）— {delay} 以内にネットワークへ"
            "サインインするまでキュー、それ以外はウォレットに返却"
        ),
        "wallet_status_treasury_empty": (
            "トレジャリーが空です — 後でもう一度シナリオを実行してください"
        ),
        "wallet_status_treasury_cap": "トレジャリー上限に達しました",
        "wallet_err_unknown_account": "不明なアカウント",
        "wallet_err_invalid_password": "パスワードが無効です",
        "wallet_err_generic": "問題が発生しました — もう一度お試しください",
        "wallet_err_address_empty": "受取人の PERC アドレスを入力してください",
        "wallet_err_address_confidential": (
            "有効な機密 PERC アドレスを入力してください"
        ),
        "wallet_err_address_invalid": "有効な PERC アドレスを入力してください",
        "wallet_password_mismatch": "パスワードが一致しません",
        "wallet_endpoint_label": "エンドポイント: {endpoint}",
        "wallet_tx_microblock_seal": "Chronoflux マイクロブロック封印",
        "wallet_login_language_label": "言語",
        "wallet_inbound_revert_days": "24 hours",
        "wallet_inbound_revert_hours": "24 hours",
        "wallet_inbound_revert_seconds": "a short time",
        "wallet_status_faucet_credited": "+{amount} {symbol}",
        "wallet_faucet_label_percent": "確率パーセント分析",
        "wallet_faucet_label_scs": "社会結束スコア分析",
    },
}