import 'app_localizations.dart';

/// Resolves wallet provider status/error keys with optional placeholders.
class WalletMessageLocalization {
  const WalletMessageLocalization(this.strings);

  final AppLocalizations strings;

  String? format(String? key, [Map<String, String> args = const {}]) {
    if (key == null || key.isEmpty) return null;
    var text = strings.t(key);
    final delayKey = args['delayKey'];
    if (delayKey != null) {
      text = text.replaceAll('{delay}', strings.t(delayKey));
    }
    for (final entry in args.entries) {
      if (entry.key == 'delayKey') continue;
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  String scenarioLabel(String? label) {
    if (label == null || label.isEmpty) return strings.t('wallet_tx_reward');
    if (label.startsWith('wallet_')) return strings.t(label);
    return label;
  }

  /// Wrong username or password on the wallet login form.
  static bool isCredentialError(String? key) =>
      key == 'wallet_err_unknown_account' ||
      key == 'wallet_err_invalid_password';

  /// Maps ledger/auth exceptions to localized wallet error keys.
  ///
  /// Known recoverable failures must not fall through to [wallet_err_generic]
  /// (shown as “Something went wrong — try again”).
  static String errorKeyFromException(Object error) {
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^(StateError|Exception|Error):\s*'), '')
        .trim();
    final lower = raw.toLowerCase();

    if (raw.contains('Unknown account')) return 'wallet_err_unknown_account';
    if (raw.contains('Invalid password')) return 'wallet_err_invalid_password';
    if (raw.contains('Cannot send to yourself')) {
      return 'wallet_err_send_to_yourself';
    }
    if (raw.contains('Manual treasury funding forbidden')) {
      return 'wallet_err_treasury_no_manual_funding';
    }
    if (raw.contains('Username already taken') ||
        raw.contains('already registered with a different address')) {
      return 'wallet_err_username_taken';
    }
    if (raw.contains('Username must be 3') || raw.contains('3–24 characters')) {
      return 'wallet_err_username_length';
    }
    if (raw.contains('lowercase letters, numbers, and underscores')) {
      return 'wallet_err_username_chars';
    }
    if (raw.contains('username is reserved') ||
        raw.contains('ward moderator username is reserved')) {
      return 'wallet_err_username_reserved';
    }
    if (raw.contains('Password must be at least')) {
      return 'wallet_err_password_short';
    }
    if (raw.contains('Registration already in progress')) {
      return 'wallet_err_registration_in_progress';
    }
    if (raw.contains('Generate a seed phrase before continuing')) {
      return 'wallet_err_seed_phrase_required';
    }
    if (raw.contains('Wallet security commitment mismatch')) {
      // Password path already verified before this is thrown; surface as auth.
      return 'wallet_err_invalid_password';
    }
    if (raw.contains('No seed recovery envelope found')) {
      return 'wallet_err_seed_recovery_not_found';
    }
    if (raw.contains('Seed recovery requires network rendezvous')) {
      return 'wallet_err_seed_recovery_offline';
    }
    if (raw.contains('Backup passphrase must be at least')) {
      return 'wallet_err_backup_passphrase_short';
    }
    if (raw.contains('syncing') || raw.contains('Wallet syncing to network')) {
      return 'wallet_sync_partial';
    }
    // Transient network / seed connectivity — wallet often still usable locally.
    if (lower.contains('socketexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('software caused connection abort') ||
        lower.contains('semaphore timeout') ||
        raw.contains('Cannot reach the seed') ||
        raw.contains('seed node')) {
      return 'wallet_sync_seed_offline';
    }
    return 'wallet_err_generic';
  }

  static String? addressErrorKey(String? validationError) {
    if (validationError == null) return null;
    if (validationError.contains('confidential')) {
      return 'wallet_err_address_confidential';
    }
    if (validationError.contains('recipient')) {
      return 'wallet_err_address_empty';
    }
    return 'wallet_err_address_invalid';
  }
}