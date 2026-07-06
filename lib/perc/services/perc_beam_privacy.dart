import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Beam-privacy fork — confidential Perccent addresses and shielded display.
class PercBeamPrivacy {
  const PercBeamPrivacy._();

  static const String confidentialPrefix = 'percpriv1';
  static const bool enabled = true;

  static String deriveConfidentialAddress(String username, String salt) {
    final digest = sha256
        .convert(utf8.encode('beam-confidential:$username:$salt'))
        .toString();
    return '$confidentialPrefix${digest.substring(0, 40)}';
  }

  static String shieldAddress(String address, {bool reveal = false}) {
    if (!enabled || reveal || address.length <= 16) return address;
    return '${address.substring(0, 10)}···${address.substring(address.length - 6)}';
  }

  static String shieldAmount(String display, {bool reveal = false}) {
    if (!enabled || reveal) return display;
    return '••••••••';
  }
}