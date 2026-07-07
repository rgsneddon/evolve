import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'perc_ledger.dart';

/// Versioned encrypted backup of full [PercLedger] state.
class PercWalletBackup {
  const PercWalletBackup._();

  static const String formatId = 'perc-wallet-backup-v1';
  static const int pbkdf2Iterations = 120000;

  static Uint8List exportEncrypted({
    required PercLedger ledger,
    required String passphrase,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final nonce = Uint8List.fromList(List.generate(12, (_) => rng.nextInt(256)));
    final key = _deriveKey(passphrase, salt);
    final plaintext = utf8.encode(jsonEncode(ledger.toJson()));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    final ciphertext = cipher.process(Uint8List.fromList(plaintext));
    final envelope = {
      'format': formatId,
      'version': 1,
      'kdf': 'pbkdf2-sha256',
      'iterations': pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  static PercLedger importEncrypted({
    required Uint8List bytes,
    required String passphrase,
  }) {
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (envelope['format'] != formatId) {
      throw FormatException('Unsupported backup format: ${envelope['format']}');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    final iterations = envelope['iterations'] as int? ?? pbkdf2Iterations;
    final key = _deriveKey(passphrase, salt, iterations: iterations);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    final plaintext = cipher.process(ciphertext);
    final ledgerJson =
        jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    return PercLedger.fromJson(ledgerJson);
  }

  static Uint8List _deriveKey(
    String passphrase,
    Uint8List salt, {
    int iterations = pbkdf2Iterations,
  }) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }
}