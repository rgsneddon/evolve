import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'perc_bip39_wordlist.dart';
import 'perc_ledger.dart';
import 'perc_wallet_backup.dart';

/// Optional 12-word BIP39-style recovery for full ledger restore.
class PercSeedRecovery {
  const PercSeedRecovery._();

  static const int wordCount = 12;

  static List<String> generateMnemonic({Random? random}) {
    final rng = random ?? Random.secure();
    final entropy = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    return _encodeMnemonic(entropy);
  }

  static String fingerprint(List<String> words) =>
      sha256.convert(utf8.encode(normalizeMnemonic(words))).toString();

  static String normalizeMnemonic(List<String> words) =>
      words.map((w) => w.trim().toLowerCase()).join(' ');

  static void validateMnemonic(List<String> words) {
    if (words.length != wordCount) {
      throw FormatException('Seed phrase must be exactly $wordCount words');
    }
    for (final word in words) {
      if (!percBip39EnglishWordlist.contains(word.trim().toLowerCase())) {
        throw FormatException('Invalid seed word: $word');
      }
    }
    final entropy = _decodeMnemonic(words);
    final checksumBits = entropy.length ~/ 4;
    final rebuilt = _encodeMnemonic(entropy);
    if (normalizeMnemonic(rebuilt) != normalizeMnemonic(words)) {
      throw FormatException('Seed phrase checksum invalid');
    }
    if (checksumBits != 4) {
      throw FormatException('Unexpected mnemonic checksum width');
    }
  }

  static Uint8List deriveKeyMaterial(List<String> words, {String passphrase = ''}) {
    validateMnemonic(words);
    final mnemonic = normalizeMnemonic(words);
    final salt = utf8.encode('mnemonic$passphrase');
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), 2048, 64));
    return derivator.process(Uint8List.fromList(utf8.encode(mnemonic)));
  }

  static Uint8List encryptLedgerEnvelope({
    required PercLedger ledger,
    required List<String> words,
  }) {
    final key = deriveKeyMaterial(words);
    final passphrase = base64Encode(key);
    return PercWalletBackup.exportEncrypted(ledger: ledger, passphrase: passphrase);
  }

  static PercLedger decryptLedgerEnvelope({
    required Uint8List envelope,
    required List<String> words,
  }) {
    final key = deriveKeyMaterial(words);
    final passphrase = base64Encode(key);
    return PercWalletBackup.importEncrypted(bytes: envelope, passphrase: passphrase);
  }

  static List<String> _encodeMnemonic(Uint8List entropy) {
    if (entropy.length != 16) {
      throw ArgumentError('Expected 128-bit entropy for 12 words');
    }
    final hash = sha256.convert(entropy).bytes;
    final bits = StringBuffer();
    for (final b in entropy) {
      bits.write(b.toRadixString(2).padLeft(8, '0'));
    }
    bits.write(hash[0].toRadixString(2).padLeft(8, '0').substring(0, 4));
    final bitString = bits.toString();
    final words = <String>[];
    for (var i = 0; i < wordCount; i++) {
      final idx = int.parse(bitString.substring(i * 11, (i + 1) * 11), radix: 2);
      words.add(percBip39EnglishWordlist[idx]);
    }
    return words;
  }

  static Uint8List _decodeMnemonic(List<String> words) {
    final bitString = StringBuffer();
    for (final word in words) {
      final idx = percBip39EnglishWordlist.indexOf(word.trim().toLowerCase());
      if (idx < 0) throw FormatException('Unknown word: $word');
      bitString.write(idx.toRadixString(2).padLeft(11, '0'));
    }
    final bits = bitString.toString();
    final entropyBits = bits.substring(0, 128);
    final entropy = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      entropy[i] = int.parse(entropyBits.substring(i * 8, (i + 1) * 8), radix: 2);
    }
    return entropy;
  }
}