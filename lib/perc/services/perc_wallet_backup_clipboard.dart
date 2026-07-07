import 'dart:convert';
import 'dart:typed_data';

import 'perc_wallet_backup.dart';

/// Clipboard / paste decoding for `.percbackup` payloads (web and manual paste).
class PercWalletBackupClipboard {
  const PercWalletBackupClipboard._();

  static const String webPrefix = 'PERCBACKUP1:';

  static Uint8List? decode(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith(webPrefix)) {
      try {
        return base64Decode(trimmed.substring(webPrefix.length));
      } catch (_) {
        return null;
      }
    }

    try {
      final envelope = jsonDecode(trimmed);
      if (envelope is Map &&
          envelope['format'] == PercWalletBackup.formatId) {
        return Uint8List.fromList(utf8.encode(trimmed));
      }
    } catch (_) {}

    return null;
  }

  static String encodeForClipboard(Uint8List bytes) =>
      '$webPrefix${base64Encode(bytes)}';
}