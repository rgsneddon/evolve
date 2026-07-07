import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../providers/perc_wallet_provider.dart';
import 'wallet_creator_credit.dart';
import 'wallet_credential_error_banner.dart';
import 'wallet_language_selector.dart';
import '../../l10n/wallet_message_localization.dart';

/// Compact wallet sign-in / registration form (splash and wallet tab).
class WalletAuthPanel extends StatefulWidget {
  const WalletAuthPanel({
    super.key,
    this.compact = false,
    this.showAppGateNote = true,
    this.showCreatorCredit = true,
  });

  final bool compact;
  final bool showAppGateNote;
  final bool showCreatorCredit;

  @override
  State<WalletAuthPanel> createState() => WalletAuthPanelState();
}

class WalletAuthPanelState extends State<WalletAuthPanel> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _credentialErrorKey = GlobalKey<WalletCredentialErrorBannerState>();
  bool _registerMode = false;
  bool _registerDefaultSet = false;

  void dismissCredentialError() {
    _credentialErrorKey.currentState?.dismiss();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final strings =
        AppLocalizations.of(context.read<LocaleProvider>().config);

    if (!_registerDefaultSet && wallet.isReady && !wallet.isLoggedIn) {
      _registerDefaultSet = true;
      _registerMode = !wallet.hasNonTreasuryAccounts;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showAppGateNote && !wallet.hasAppAccess) ...[
          Text(
            strings.t('wallet_app_gate_title'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            strings.t('wallet_app_gate_note'),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9BA3B8),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
        ],
        if (wallet.sessionTimedOut) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3A2A14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              strings.t('wallet_session_expired'),
              style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          _registerMode
              ? strings.t('wallet_register_title')
              : strings.t('wallet_login_title'),
          style: TextStyle(
            fontSize: widget.compact ? 16 : 18,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _registerMode
              ? strings.t('wallet_register_note')
              : strings.t('wallet_login_note'),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9BA3B8),
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        const WalletLanguageSelector(),
        const SizedBox(height: 10),
        TextField(
          controller: _usernameCtrl,
          decoration: InputDecoration(
            labelText: _registerMode
                ? strings.t('wallet_choose_username')
                : strings.t('wallet_username'),
            hintText:
                _registerMode ? strings.t('wallet_username_hint') : null,
            helperText:
                _registerMode ? strings.t('wallet_username_rules') : null,
            filled: true,
            fillColor: const Color(0xFF1A2030),
          ),
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: strings.t('wallet_password'),
            filled: true,
            fillColor: const Color(0xFF1A2030),
          ),
          onSubmitted: (_) => _submit(wallet, strings),
        ),
        if (WalletMessageLocalization.isCredentialError(wallet.errorMessage)) ...[
          const SizedBox(height: 8),
          WalletCredentialErrorBanner(
            key: _credentialErrorKey,
            errorKey: wallet.errorMessage,
            message: wallet.localizedErrorMessage(strings),
            onFadeComplete: wallet.clearCredentialError,
          ),
        ] else if (wallet.localizedErrorMessage(strings) != null) ...[
          const SizedBox(height: 8),
          Text(
            wallet.localizedErrorMessage(strings)!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => _submit(wallet, strings),
          child: Text(
            _registerMode
                ? strings.t('wallet_register')
                : strings.t('wallet_sign_in'),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _registerMode = !_registerMode),
          child: Text(
            _registerMode
                ? strings.t('wallet_sign_in')
                : strings.t('wallet_register'),
          ),
        ),
        if (widget.showCreatorCredit && !widget.compact)
          WalletCreatorCredit(strings: strings),
      ],
    );
  }

  Future<void> _submit(
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) async {
    if (_registerMode) {
      await wallet.register(_usernameCtrl.text, _passwordCtrl.text);
    } else {
      wallet.login(_usernameCtrl.text, _passwordCtrl.text);
    }
  }
}