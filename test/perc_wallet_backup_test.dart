import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_wallet_backup.dart';

void main() {
  test('encrypt decrypt round-trips full ledger equality', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('treasury-pass');
    ledger.launchBlockchain();
    ledger.register('alice', 'password123');
    ledger.login('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 42);
    ledger.recordMicroblock(
      input: const ScenarioInput(
        topic: 'backup-test',
        posedQuestion: 'Will backup round-trip?',
      ),
      locale: LocaleConfig.defaults,
      activity: 'fair_usage',
      activityLabel: 'test',
    );

    final exported = PercWalletBackup.exportEncrypted(
      ledger: ledger,
      passphrase: 'backup-passphrase-9',
    );
    final restored = PercWalletBackup.importEncrypted(
      bytes: exported,
      passphrase: 'backup-passphrase-9',
    );

    expect(restored.account('alice')!.balance.microUnits,
        ledger.account('alice')!.balance.microUnits);
    expect(restored.account('alice')!.scenarioBlockHeight,
        ledger.account('alice')!.scenarioBlockHeight);
    expect(restored.microblockLog.length, ledger.microblockLog.length);
    expect(restored.pendingInboundTransfers.length,
        ledger.pendingInboundTransfers.length);
    expect(restored.blockHeight, ledger.blockHeight);
  });
}