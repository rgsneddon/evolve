import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_seed_recovery.dart';

void main() {
  test('blank ledger recovers from seed catalog fingerprint map', () {
    final source = PercLedger.empty();
    source.ensureTreasuryAccount();
    source.setupTreasuryPassword('treasury-pass');
    source.launchBlockchain();
    source.register('erin', 'password123');
    source.login('erin', 'password123');

    final mnemonic = PercSeedRecovery.generateMnemonic();
    source.attachSeedRecoveryEnvelope(username: 'erin', mnemonic: mnemonic);

    final blank = PercLedger.empty();
    expect(blank.tryRecoverFromSeedEnvelope(mnemonic: mnemonic), isNull);

    blank.seedRecoveryCatalog[PercSeedRecovery.fingerprint(mnemonic)] =
        source.seedRecoveryCatalog.values.first;

    final restored = blank.recoverFromSeedEnvelope(mnemonic: mnemonic);
    expect(restored.account('erin')!.balance.microUnits,
        source.account('erin')!.balance.microUnits);
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