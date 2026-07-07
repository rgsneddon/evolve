import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_backup.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
  });

  test('hub restore from exported backup preserves session balances and scenario height', () async {
    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);
    final ledger = PercLedgerHub.instance.ledger;
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('treasury-pass');
    ledger.launchBlockchain();
    ledger.register('dave', 'password123');
    ledger.login('dave', 'password123');
    ledger.creditScenario(username: 'dave', percentChance: 33);
    ledger.recordMicroblock(
      input: const ScenarioInput(topic: 'roundtrip', posedQuestion: 'ok?'),
      locale: LocaleConfig.defaults,
    );

    final beforeBalance = ledger.account('dave')!.balance.microUnits;
    final beforeScenario = ledger.account('dave')!.scenarioBlockHeight;

    final bytes = PercWalletBackup.exportEncrypted(
      ledger: ledger.snapshotForBackup(),
      passphrase: 'roundtrip-pass-phrase',
    );
    final restored = PercWalletBackup.importEncrypted(
      bytes: bytes,
      passphrase: 'roundtrip-pass-phrase',
    );

    await PercLedgerHub.instance.restoreFromBackup(restored, sessionUsername: 'dave');

    final after = PercLedgerHub.instance.ledger;
    expect(after.sessionUsername, 'dave');
    expect(after.account('dave')!.balance.microUnits, beforeBalance);
    expect(after.account('dave')!.scenarioBlockHeight, beforeScenario);
  });
}