import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_seed_recovery.dart';
import 'package:evolve/perc/services/perc_wallet_backup.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/services/security_recovery_service.dart';
import 'package:evolve/l10n/wallet_message_localization.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  PercLedger _sourceLedger() {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('treasury-pass');
    ledger.launchBlockchain();
    ledger.register('erin', 'password123');
    ledger.login('erin', 'password123');
    ledger.creditScenario(username: 'erin', percentChance: 40);
    ledger.recordMicroblock(
      input: const ScenarioInput(topic: 'service', posedQuestion: 'recover?'),
      locale: LocaleConfig.defaults,
    );
    return ledger;
  }

  test(
    'recovers full ledger from seed via injected SeedEnvelopeFetcher on blank ledger',
    () async {
      final source = _sourceLedger();
      final mnemonic = PercSeedRecovery.generateMnemonic();
      source.attachSeedRecoveryEnvelope(username: 'erin', mnemonic: mnemonic);
      final fp = PercSeedRecovery.fingerprint(mnemonic);
      final envelopeB64 = source.seedRecoveryCatalog[fp]!;

      String? fetchedFingerprint;
      final service = SecurityRecoveryService(
        ports: SecurityRecoveryPorts(
          resolveBackupBytes: () async => null,
          fetchSeedEnvelope: (fingerprint) async {
            fetchedFingerprint = fingerprint;
            return envelopeB64;
          },
          isNetworkConfigured: () async => true,
        ),
      );

      final blank = PercLedger.empty();
      final restored = await service.recoverLedgerFromSeed(
        ledger: blank,
        words: mnemonic,
      );

      expect(fetchedFingerprint, fp);
      expect(restored.account('erin')!.balance.microUnits,
          source.account('erin')!.balance.microUnits);
      expect(restored.account('erin')!.scenarioBlockHeight,
          source.account('erin')!.scenarioBlockHeight);
      expect(restored.microblockLog.length, source.microblockLog.length);
    },
  );

  test('throws offline error when fetcher returns null and network unavailable',
      () async {
    final mnemonic = PercSeedRecovery.generateMnemonic();
    final service = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async => null,
        fetchSeedEnvelope: (_) async => null,
        isNetworkConfigured: () async => false,
      ),
    );

    expect(
      () => service.recoverLedgerFromSeed(
        ledger: PercLedger.empty(),
        words: mnemonic,
      ),
      throwsStateError,
    );
  });

  test('provider recoverFromSeedPhrase fetches envelope via rendezvous override',
      () async {
    final source = _sourceLedger();
    final mnemonic = PercSeedRecovery.generateMnemonic();
    source.attachSeedRecoveryEnvelope(username: 'erin', mnemonic: mnemonic);
    final fp = PercSeedRecovery.fingerprint(mnemonic);
    final envelopeB64 = source.seedRecoveryCatalog[fp]!;

    PercLedgerHub.resetForTest();
    final recovery = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async => null,
        fetchSeedEnvelope: (_) async => envelopeB64,
        isNetworkConfigured: () async => true,
      ),
    );
    final wallet = PercWalletProvider(
      store: PercWalletStoreMemory(),
      recoveryService: recovery,
    );
    await wallet.initialize();

    await wallet.recoverFromSeedPhrase(mnemonic);

    final ledger = PercLedgerHub.instance.ledger;
    expect(ledger.sessionUsername, 'erin');
    expect(
      ledger.account('erin')!.balance.microUnits,
      source.account('erin')!.balance.microUnits,
    );
    expect(
      ledger.account('erin')!.scenarioBlockHeight,
      source.account('erin')!.scenarioBlockHeight,
    );
    expect(ledger.microblockLog.length, source.microblockLog.length);
  });

  test('decodes PERCBACKUP1 clipboard text and restores ledger equality', () async {
    final source = _sourceLedger();
    final passphrase = 'clipboard-passphrase';
    final bytes = PercWalletBackup.exportEncrypted(
      ledger: source.snapshotForBackup(),
      passphrase: passphrase,
    );
    final clipboardText = SecurityRecoveryService.encodeBackupForClipboard(bytes);

    final decoded = SecurityRecoveryService.decodeBackupText(clipboardText);
    expect(decoded, isNotNull);

    final service = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async => decoded,
        fetchSeedEnvelope: (_) async => null,
        isNetworkConfigured: () async => false,
      ),
    );

    final resolved = await service.resolveBackupBytes();
    final restored = service.importEncryptedBackup(
      bytes: resolved!,
      passphrase: passphrase,
    );

    expect(restored.account('erin')!.balance.microUnits,
        source.account('erin')!.balance.microUnits);
    expect(restored.account('erin')!.scenarioBlockHeight,
        source.account('erin')!.scenarioBlockHeight);
    expect(restored.microblockLog.length, source.microblockLog.length);
  });

  test('provider surfaces offline seed recovery error key', () async {
    final mnemonic = PercSeedRecovery.generateMnemonic();
    final recovery = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async => null,
        fetchSeedEnvelope: (_) async => null,
        isNetworkConfigured: () async => false,
      ),
    );
    final wallet = PercWalletProvider(
      store: PercWalletStoreMemory(),
      recoveryService: recovery,
    );
    await wallet.initialize();

    await expectLater(
      () => wallet.recoverFromSeedPhrase(mnemonic),
      throwsStateError,
    );
    expect(wallet.errorMessage, 'wallet_err_seed_recovery_offline');
    expect(
      WalletMessageLocalization.errorKeyFromException(
        StateError('Seed recovery requires network rendezvous'),
      ),
      'wallet_err_seed_recovery_offline',
    );
  });
}