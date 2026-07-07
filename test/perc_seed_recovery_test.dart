import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_seed_recovery.dart';

void main() {
  test('seed envelope round-trips ledger including scenario and microblock log', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('treasury-pass');
    ledger.launchBlockchain();
    ledger.register('carol', 'password123');
    ledger.login('carol', 'password123');
    ledger.creditScenario(username: 'carol', percentChance: 55);
    ledger.recordMicroblock(
      input: const ScenarioInput(topic: 'seed', posedQuestion: 'recover?'),
      locale: LocaleConfig.defaults,
    );

    final mnemonic = PercSeedRecovery.generateMnemonic();
    ledger.attachSeedRecoveryEnvelope(username: 'carol', mnemonic: mnemonic);

    final restored = ledger.recoverFromSeedEnvelope(
      mnemonic: mnemonic,
      expectedFingerprint: PercSeedRecovery.fingerprint(mnemonic),
    );

    expect(restored.account('carol')!.scenarioBlockHeight,
        ledger.account('carol')!.scenarioBlockHeight);
    expect(restored.account('carol')!.balance.microUnits,
        ledger.account('carol')!.balance.microUnits);
    expect(restored.microblockLog.length, ledger.microblockLog.length);
    expect(restored.blockHeight, ledger.blockHeight);
  });

  test('mnemonic checksum rejects corrupted word', () {
    final words = PercSeedRecovery.generateMnemonic();
    final bad = List<String>.from(words)..[0] = 'zzzzzz';
    expect(
      () => PercSeedRecovery.validateMnemonic(bad),
      throwsFormatException,
    );
  });
}