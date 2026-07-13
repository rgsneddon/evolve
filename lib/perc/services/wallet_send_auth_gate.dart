import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../providers/perc_wallet_provider.dart';
import '../widgets/wallet_biometric_auth_ui.dart';
import '../widgets/wallet_password_field.dart';
import 'wallet_biometric_credential_store.dart';

/// Password or Android biometric confirmation before outbound PERC sends.
class WalletSendAuthGate {
  const WalletSendAuthGate._();

  @visibleForTesting
  static WalletBiometricCredentialStore? biometricStoreOverride;

  static WalletBiometricCredentialStore get _store =>
      biometricStoreOverride ?? WalletBiometricAuthUi.store;

  static Future<String?> requestAuthorization({
    required BuildContext context,
    required PercWalletProvider wallet,
    required AppLocalizations strings,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SendAuthDialog(
        wallet: wallet,
        strings: strings,
        store: _store,
      ),
    );
  }
}

class _SendAuthDialog extends StatefulWidget {
  const _SendAuthDialog({
    required this.wallet,
    required this.strings,
    required this.store,
  });

  final PercWalletProvider wallet;
  final AppLocalizations strings;
  final WalletBiometricCredentialStore store;

  @override
  State<_SendAuthDialog> createState() => _SendAuthDialogState();
}

class _SendAuthDialogState extends State<_SendAuthDialog> {
  final _passwordCtrl = TextEditingController();
  bool _hasBiometricCredentials = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final has = await widget.store.hasStoredCredentials();
    if (!mounted) return;
    setState(() => _hasBiometricCredentials = has);
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _showBiometric {
    return WalletBiometricAuthUi.showBiometricSignIn(
      loginMode: true,
      hasStoredCredentials: _hasBiometricCredentials,
    );
  }

  void _completeWithPassword(String password) {
    if (!widget.wallet.verifySendAuthPassword(password)) {
      setState(() => _errorKey = 'wallet_err_invalid_password');
      return;
    }
    Navigator.pop(context, password);
  }

  Future<void> _signInWithBiometric() async {
    final creds = await widget.store.unlockWithBiometric(
      localizedReason: widget.strings.t('wallet_send_auth_biometric_reason'),
    );
    if (!mounted) return;
    if (creds == null) return;
    final session = widget.wallet.loggedInUsername;
    if (session == null ||
        creds.username.toLowerCase() != session.toLowerCase()) {
      setState(() => _errorKey = 'wallet_err_invalid_password');
      return;
    }
    _completeWithPassword(creds.password);
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(strings.t('wallet_send_auth_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.t('wallet_send_auth_message'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
          ),
          const SizedBox(height: 12),
          WalletPasswordField(
            controller: _passwordCtrl,
            labelText: strings.t('wallet_password'),
            onSubmitted: (_) => _completeWithPassword(_passwordCtrl.text),
          ),
          if (_errorKey != null) ...[
            const SizedBox(height: 8),
            Text(
              strings.t(_errorKey!),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (_showBiometric) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _signInWithBiometric,
              icon: const Icon(Icons.fingerprint),
              label: Text(strings.t('wallet_biometric_sign_in')),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _completeWithPassword(_passwordCtrl.text),
          child: Text(strings.t('wallet_send_auth_confirm')),
        ),
      ],
    );
  }
}