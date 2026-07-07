import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/screens/security_screen.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_backup.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'test_locale_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  Future<PercWalletProvider> bootWallet() async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('secuser', 'password12345', enableSeedRecovery: true);
    final ledger = PercLedgerHub.instance.ledger;
    ledger.creditScenario(username: 'secuser', percentChance: 42);
    ledger.recordMicroblock(
      input: const ScenarioInput(topic: 'security-ui', posedQuestion: 'ok?'),
      locale: LocaleConfig.defaults,
    );
    return wallet;
  }

  testWidgets('Security screen restores encrypted backup on blank store', (
    tester,
  ) async {
    final wallet = await bootWallet();
    final ledger = PercLedgerHub.instance.ledger;
    final balanceBefore = ledger.account('secuser')!.balance.microUnits;
    final scenarioBefore = ledger.account('secuser')!.scenarioBlockHeight;

    final bytes = PercWalletBackup.exportEncrypted(
      ledger: ledger.snapshotForBackup(),
      passphrase: 'backup-passphrase',
    );

    PercLedgerHub.resetForTest();
    final blank = PercWalletProvider(store: PercWalletStoreMemory());
    await blank.initialize();
    final locale = await createTestLocaleProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: blank),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: const MaterialApp(home: SecurityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await blank.restoreFromEncryptedBackup(bytes, 'backup-passphrase');
    await tester.pump();

    final restoredLedger = PercLedgerHub.instance.ledger;
    expect(restoredLedger.sessionUsername, 'secuser');
    expect(
      restoredLedger.account('secuser')!.balance.microUnits,
      balanceBefore,
    );
    expect(
      restoredLedger.account('secuser')!.scenarioBlockHeight,
      scenarioBefore,
    );
    expect(blank.isLoggedIn, isTrue);
  });
}