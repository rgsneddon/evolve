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

  /// Maps ledger/auth exceptions to localized wallet error keys.
  static String errorKeyFromException(Object error) {
    final raw = error.toString().replaceFirst('StateError: ', '').trim();
    if (raw.contains('Unknown account')) return 'wallet_err_unknown_account';
    if (raw.contains('Invalid password')) return 'wallet_err_invalid_password';
    if (raw.contains('Cannot send to yourself')) {
      return 'wallet_err_send_to_yourself';
    }
    if (raw.contains('syncing')) return 'wallet_sync_partial';
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