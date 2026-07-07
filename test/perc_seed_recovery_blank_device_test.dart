import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_network_rendezvous.dart';
import 'package:evolve/perc/services/perc_seed_recovery.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercNetworkRendezvous.fetchSeedRecoveryOverride = null;
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercNetworkRendezvous.fetchSeedRecoveryOverride = null;
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  PercLedger _sourceLedgerWithSeed() {
    final source = PercLedger.empty();
    source.ensureTreasuryAccount();
    source.setupTreasuryPassword('treasury-pass');
    source.launchBlockchain();
    source.register('erin', 'password123');
    source.login('erin', 'password123');
    source.creditScenario(username: 'erin', percentChance: 40);
    source.recordMicroblock(
      input: const ScenarioInput(topic: 'catalog', posedQuestion: 'recover?'),
      locale: LocaleConfig.defaults,
    );
    return source;
  }

  test('blank ledger recovers from seed catalog fingerprint map', () {
    final source = _sourceLedgerWithSeed();
    final mnemonic = PercSeedRecovery.generateMnemonic();
    source.attachSeedRecoveryEnvelope(username: 'erin', mnemonic: mnemonic);

    final blank = PercLedger.empty();
    expect(blank.tryRecoverFromSeedEnvelope(mnemonic: mnemonic), isNull);

    blank.seedRecoveryCatalog[PercSeedRecovery.fingerprint(mnemonic)] =
        source.seedRecoveryCatalog.values.first;

    final restored = blank.recoverFromSeedEnvelope(mnemonic: mnemonic);
    expect(restored.account('erin')!.balance.microUnits,
        source.account('erin')!.balance.microUnits);
    expect(restored.account('erin')!.scenarioBlockHeight,
        source.account('erin')!.scenarioBlockHeight);
    expect(restored.microblockLog.length, source.microblockLog.length);
  });

  test('provider recoverFromSeedPhrase fetches envelope via rendezvous override',
      () async {
    final source = _sourceLedgerWithSeed();
    final mnemonic = PercSeedRecovery.generateMnemonic();
    source.attachSeedRecoveryEnvelope(username: 'erin', mnemonic: mnemonic);
    final fp = PercSeedRecovery.fingerprint(mnemonic);
    final envelopeB64 = source.seedRecoveryCatalog[fp]!;

    PercLedgerHub.resetForTest();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();

    String? fetchedFingerprint;
    PercNetworkRendezvous.fetchSeedRecoveryOverride = (fingerprint) async {
      fetchedFingerprint = fingerprint;
      return envelopeB64;
    };

    await wallet.recoverFromSeedPhrase(mnemonic);

    expect(fetchedFingerprint, fp);
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

  test('provider surfaces offline error when rendezvous unavailable', () async {
    final mnemonic = PercSeedRecovery.generateMnemonic();
    PercLedgerHub.resetForTest();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();

    await expectLater(
      () => wallet.recoverFromSeedPhrase(mnemonic),
      throwsStateError,
    );
    expect(wallet.errorMessage, 'wallet_err_seed_recovery_offline');
  });

  test('encrypted mnemonic at rest refreshes envelope after scenario credit', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('treasury-pass');
    ledger.launchBlockchain();
    ledger.register('frank', 'password123');
    ledger.login('frank', 'password123');

    final mnemonic = PercSeedRecovery.generateMnemonic();
    ledger.attachSeedRecoveryEnvelope(username: 'frank', mnemonic: mnemonic);
    final beforeHeight = ledger.account('frank')!.scenarioBlockHeight;

    ledger.creditScenario(username: 'frank', percentChance: 60);
    ledger.refreshSeedRecoveryEnvelopes();

    final restored = ledger.recoverFromSeedEnvelope(mnemonic: mnemonic);
    expect(restored.account('frank')!.scenarioBlockHeight, greaterThan(beforeHeight));
  });

  test('login rejects tampered password switch commitment', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.register('grace', 'password123');
    final acc = ledger.account('grace')!;
    acc.passwordSwitchCommit = '${acc.passwordSwitchCommit}x';

    expect(
      () => ledger.login('grace', 'password123'),
      throwsStateError,
    );
  });
}