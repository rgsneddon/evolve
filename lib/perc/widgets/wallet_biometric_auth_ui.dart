import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/wallet_biometric_credential_store.dart';

/// Android biometric sign-in affordance + post-login enrollment dialog.
class WalletBiometricAuthUi {
  const WalletBiometricAuthUi._();

  static final WalletBiometricCredentialStore store =
      WalletBiometricCredentialStore();

  static bool showBiometricSignIn({
    required bool loginMode,
    required bool hasStoredCredentials,
  }) {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return loginMode && hasStoredCredentials;
  }

  static Widget? biometricSignInButton({
    required BuildContext context,
    required AppLocalizations strings,
    required PercWalletProvider wallet,
    required VoidCallback onSignedIn,
    required TextEditingController usernameController,
    required TextEditingController passwordController,
  }) {
    return OutlinedButton.icon(
      onPressed: () => _signInWithBiometric(
        context: context,
        strings: strings,
        wallet: wallet,
        onSignedIn: onSignedIn,
        usernameController: usernameController,
        passwordController: passwordController,
      ),
      icon: const Icon(Icons.fingerprint),
      label: Text(strings.t('wallet_biometric_sign_in')),
    );
  }

  static Future<void> _signInWithBiometric({
    required BuildContext context,
    required AppLocalizations strings,
    required PercWalletProvider wallet,
    required VoidCallback onSignedIn,
    required TextEditingController usernameController,
    required TextEditingController passwordController,
  }) async {
    final creds = await store.unlockWithBiometric(
      localizedReason: strings.t('wallet_biometric_auth_reason'),
    );
    if (creds == null || !context.mounted) return;
    usernameController.text = creds.username;
    passwordController.text = creds.password;
    await wallet.login(creds.username, creds.password);
    if (wallet.isLoggedIn && wallet.errorMessage == null) {
      onSignedIn();
    }
  }

  /// Offers biometric enrollment when the device supports it and nothing is stored yet.
  static Future<void> offerEnrollmentIfNeeded({
    required BuildContext context,
    required AppLocalizations strings,
    required String username,
    required String password,
  }) async {
    if (await store.hasStoredCredentials()) return;
    await offerEnrollmentAfterLogin(
      context: context,
      strings: strings,
      username: username,
      password: password,
    );
  }

  static Future<void> offerEnrollmentAfterLogin({
    required BuildContext context,
    required AppLocalizations strings,
    required String username,
    required String password,
  }) async {
    if (!await store.isBiometricAvailableOnDevice()) return;
    if (!context.mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('wallet_biometric_enable_title')),
        content: Text(strings.t('wallet_biometric_enable_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.t('wallet_biometric_not_now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.t('wallet_biometric_enable')),
          ),
        ],
      ),
    );
    if (accept == true) {
      await store.saveCredentials(username: username, password: password);
    }
  }
}