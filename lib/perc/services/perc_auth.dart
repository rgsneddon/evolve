import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../perc_chain_constants.dart';
import 'perc_beam_privacy.dart';

class PercAuth {
  const PercAuth._();

  static String generateSalt([Random? random]) {
    final r = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String deriveAddress(String username, String salt) {
    if (PercChainConstants.beamPrivacyEnabled) {
      return PercBeamPrivacy.deriveConfidentialAddress(username, salt);
    }
    final digest = sha256.convert(utf8.encode('perc:$username:$salt')).toString();
    return 'perc1${digest.substring(0, 40)}';
  }

  static bool verifyPassword({
    required String password,
    required String salt,
    required String expectedHash,
  }) =>
      hashPassword(password, salt) == expectedHash;

  /// System usernames — not available for self-registration.
  static const reservedUsernames = <String>{
    PercChainConstants.treasuryUsername,
    'rgsneddon',
    'rgsnedds',
  };

  static String? validateUsername(String username) {
    final u = username.trim().toLowerCase();
    if (u.length < 3 || u.length > 24) {
      return 'Username must be 3–24 characters';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(u)) {
      return 'Use lowercase letters, numbers, and underscores only';
    }
    if (reservedUsernames.contains(u)) {
      return 'That username is reserved — choose another';
    }
    return null;
  }

  static String? validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();

  static bool isTreasuryUsername(String username) =>
      normalizeUsername(username) == PercChainConstants.treasuryUsername;

  static String normalizeAddress(String address) => address.trim();

  static String? validateAddress(String address) {
    final a = normalizeAddress(address);
    if (a.isEmpty) return 'Enter a recipient PERC address';
    if (PercChainConstants.beamPrivacyEnabled) {
      final prefix = PercBeamPrivacy.confidentialPrefix;
      if (!a.startsWith(prefix) || a.length != prefix.length + 40) {
        return 'Enter a valid confidential PERC address';
      }
      return null;
    }
    if (!a.startsWith('perc1') || a.length != 45) {
      return 'Enter a valid PERC address';
    }
    return null;
  }
}