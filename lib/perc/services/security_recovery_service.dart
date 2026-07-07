import 'dart:convert';
import 'dart:typed_data';

import '../perc_chain_constants.dart';
import 'perc_ledger.dart';
import 'perc_network_rendezvous.dart';
import 'perc_seed_recovery.dart';
import 'perc_wallet_backup.dart';
import 'perc_wallet_backup_clipboard.dart';
import 'security_recovery_backup_resolver.dart';

/// Resolves encrypted backup bytes (clipboard, file picker, or test injection).
typedef BackupBytesResolver = Future<Uint8List?> Function();

/// Fetches a seed recovery envelope from the network rendezvous.
typedef SeedEnvelopeFetcher = Future<String?> Function(String fingerprint);

/// Whether a rendezvous URL is configured for cross-device seed recovery.
typedef NetworkConfiguredChecker = Future<bool> Function();

/// Injectable ports for backup and seed recovery orchestration.
class SecurityRecoveryPorts {
  const SecurityRecoveryPorts({
    required this.resolveBackupBytes,
    required this.fetchSeedEnvelope,
    required this.isNetworkConfigured,
  });

  final BackupBytesResolver resolveBackupBytes;
  final SeedEnvelopeFetcher fetchSeedEnvelope;
  final NetworkConfiguredChecker isNetworkConfigured;

  factory SecurityRecoveryPorts.production() => SecurityRecoveryPorts(
        resolveBackupBytes: resolveBackupBytesFromPlatform,
        fetchSeedEnvelope: (fingerprint) =>
            PercNetworkRendezvous().fetchSeedRecoveryEnvelope(
          fingerprint: fingerprint,
        ),
        isNetworkConfigured: () async =>
            (await PercNetworkRendezvous().baseUrl()) != null,
      );
}

/// Orchestrates Security-tab backup import and seed-phrase recovery.
class SecurityRecoveryService {
  const SecurityRecoveryService({required this.ports});

  final SecurityRecoveryPorts ports;

  factory SecurityRecoveryService.production() =>
      SecurityRecoveryService(ports: SecurityRecoveryPorts.production());

  /// Decodes pasted or file-read text into encrypted backup bytes.
  static Uint8List? decodeBackupText(String text) =>
      PercWalletBackupClipboard.decode(text);

  static String encodeBackupForClipboard(Uint8List bytes) =>
      PercWalletBackupClipboard.encodeForClipboard(bytes);

  Future<Uint8List?> resolveBackupBytes() => ports.resolveBackupBytes();

  PercLedger importEncryptedBackup({
    required Uint8List bytes,
    required String passphrase,
  }) =>
      PercWalletBackup.importEncrypted(bytes: bytes, passphrase: passphrase);

  /// Restores ledger from mnemonic using local envelopes then network fetch.
  Future<PercLedger> recoverLedgerFromSeed({
    required PercLedger ledger,
    required List<String> words,
  }) async {
    var restored = ledger.tryRecoverFromSeedEnvelope(mnemonic: words);
    if (restored != null) return restored;

    final fp = PercSeedRecovery.fingerprint(words);
    final hasNetwork = await ports.isNetworkConfigured();
    final remoteEnvelope = await ports.fetchSeedEnvelope(fp);
    if (remoteEnvelope == null) {
      throw StateError(
        hasNetwork
            ? 'No seed recovery envelope found for this phrase'
            : 'Seed recovery requires network rendezvous',
      );
    }
    return PercSeedRecovery.decryptLedgerEnvelope(
      envelope: base64Decode(remoteEnvelope),
      words: words,
    );
  }

  static String resolveSessionUsername(PercLedger restored) {
    final session = restored.sessionUsername ??
        restored.accounts.keys.firstWhere(
          (k) => k != PercChainConstants.treasuryUsername,
          orElse: () => '',
        );
    if (session.isEmpty) {
      throw StateError('Recovery snapshot contains no user wallet');
    }
    return session;
  }
}