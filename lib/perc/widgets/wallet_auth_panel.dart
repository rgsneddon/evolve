import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/perc_auth.dart';
import 'wallet_biometric_auth_ui.dart';
import 'wallet_creator_credit.dart';
import 'wallet_credential_error_banner.dart';
import 'wallet_language_selector.dart';
import 'wallet_password_field.dart';
import '../../l10n/wallet_message_localization.dart';

/// Compact wallet sign-in / registration form (splash and wallet tab).
class WalletAuthPanel extends StatefulWidget {
  const WalletAuthPanel({
    super.key,
    this.compact = false,
    this.showAppGateNote = true,
    this.showCreatorCredit = true,
    this.autoPromptBiometricOnLaunch = false,
    this.onSignedIn,
  });

  final bool compact;
  final bool showAppGateNote;
  final bool showCreatorCredit;
  final bool autoPromptBiometricOnLaunch;
  final VoidCallback? onSignedIn;

  @override
  State<WalletAuthPanel> createState() => WalletAuthPanelState();
}

class WalletAuthPanelState extends State<WalletAuthPanel> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _credentialErrorKey = GlobalKey<WalletCredentialErrorBannerState>();
  bool _registerMode = false;
  bool _registerDefaultSet = false;
  bool _hasBiometricCredentials = false;
  bool _biometricLaunchPrompted = false;

  void dismissCredentialError() {
    _credentialErrorKey.currentState?.dismiss();
  }

  @override
  void initState() {
    super.initState();
    WalletBiometricAuthUi.credentialsRevision
        .addListener(_onBiometricCredentialsChanged);
    _loadBiometricState();
  }

  void _onBiometricCredentialsChanged() {
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final has = await WalletBiometricAuthUi.store.hasStoredCredentials();
    final username = await WalletBiometricAuthUi.store.storedUsername();
    if (!mounted) return;
    setState(() => _hasBiometricCredentials = has);
    if (username != null && username.isNotEmpty) {
      _usernameCtrl.text = username;
    }
    if (_registerDefaultSet) {
      await _maybeAutoPromptBiometricOnLaunch();
    }
  }

  Future<void> _maybeAutoPromptBiometricOnLaunch() async {
    if (!mounted ||
        _biometricLaunchPrompted ||
        !_registerDefaultSet ||
        !widget.autoPromptBiometricOnLaunch ||
        _registerMode ||
        !_hasBiometricCredentials) {
      return;
    }
    final wallet = context.read<PercWalletProvider>();
    final strings =
        AppLocalizations.of(context.read<LocaleProvider>().config);
    if (!wallet.isReady ||
        wallet.isLoggedIn ||
        !wallet.hasNonTreasuryAccounts) {
      return;
    }
    if (!WalletBiometricAuthUi.showBiometricSignIn(
      loginMode: true,
      hasStoredCredentials: _hasBiometricCredentials,
    )) {
      return;
    }
    _biometricLaunchPrompted = true;
    await WalletBiometricAuthUi.attemptSignInWithBiometric(
      context: context,
      strings: strings,
      wallet: wallet,
      onSignedIn: () => widget.onSignedIn?.call(),
      usernameController: _usernameCtrl,
      passwordController: _passwordCtrl,
    );
  }

  @override
  void dispose() {
    WalletBiometricAuthUi.credentialsRevision
        .removeListener(_onBiometricCredentialsChanged);
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
      if (widget.autoPromptBiometricOnLaunch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_maybeAutoPromptBiometricOnLaunch());
        });
      }
    }

    final showBiometric = WalletBiometricAuthUi.showBiometricSignIn(
      loginMode: !_registerMode,
      hasStoredCredentials: _hasBiometricCredentials,
    );

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
        WalletPasswordField(
          controller: _passwordCtrl,
          labelText: strings.t('wallet_password'),
          filled: true,
          fillColor: const Color(0xFF1A2030),
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
        if (showBiometric) ...[
          const SizedBox(height: 12),
          WalletBiometricAuthUi.biometricSignInButton(
            context: context,
            strings: strings,
            wallet: wallet,
            usernameController: _usernameCtrl,
            passwordController: _passwordCtrl,
            onSignedIn: () => widget.onSignedIn?.call(),
          )!,
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
    final username = PercAuth.normalizeUsername(_usernameCtrl.text);
    final password = _passwordCtrl.text;
    if (_registerMode) {
      await wallet.register(username, password);
      return;
    }
    await wallet.login(username, password);
    if (!mounted) return;
    if (wallet.isLoggedIn && wallet.errorMessage == null) {
      await WalletBiometricAuthUi.offerEnrollmentIfNeeded(
        context: context,
        strings: strings,
        username: username,
        password: password,
      );
      await _loadBiometricState();
    }
  }
}