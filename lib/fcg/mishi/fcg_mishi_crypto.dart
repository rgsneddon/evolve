import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// AES-GCM encryption for the Evolve ↔ Mishi shared bridge file.
class FcgMishiCrypto {
  const FcgMishiCrypto._();

  static const String envelopeFormat = 'fcg-mishi-bridge-v1';
  static const int pbkdf2Iterations = 120000;
  static const String bridgePassphrase = 'fcg-mishi-shared-bridge-evolve';

  static Uint8List deriveBridgeKey() {
    final salt = utf8.encode('fcg-mishi-bridge-salt-v1');
    return _deriveKey(bridgePassphrase, Uint8List.fromList(salt));
  }

  static String encryptJson(Map<String, dynamic> payload, {Random? random}) {
    final rng = random ?? Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final nonce = Uint8List.fromList(List.generate(12, (_) => rng.nextInt(256)));
    final key = deriveBridgeKey();
    final plaintext = utf8.encode(jsonEncode(payload));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    final ciphertext = cipher.process(Uint8List.fromList(plaintext));
    return jsonEncode({
      'format': envelopeFormat,
      'version': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
    });
  }

  static Map<String, dynamic> decryptJson(String envelopeText) {
    final envelope = jsonDecode(envelopeText) as Map<String, dynamic>;
    if (envelope['format'] != envelopeFormat) {
      throw FormatException('Unsupported Mishi bridge format');
    }
    final nonce = base64Decode(envelope['nonce'] as String);
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    final key = deriveBridgeKey();
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    final plain = cipher.process(ciphertext);
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(passphrase)));
  }
}