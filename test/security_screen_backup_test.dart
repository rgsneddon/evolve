import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/screens/security_screen.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/services/security_recovery_service.dart';
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
    await wallet.register('secuser', 'password12345');
    final ledger = PercLedgerHub.instance.ledger;
    ledger.creditScenario(username: 'secuser', percentChance: 42);
    ledger.recordMicroblock(
      input: const ScenarioInput(topic: 'security-ui', posedQuestion: 'ok?'),
      locale: LocaleConfig.defaults,
    );
    return wallet;
  }

  Future<void> pumpSecurity(
    WidgetTester tester,
    PercWalletProvider wallet, {
    SecurityRecoveryService? recoveryService,
  }) async {
    final locale = await createTestLocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          home: SecurityScreen(recoveryService: recoveryService),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Security tab export button captures encrypted backup bytes', (
    tester,
  ) async {
    Uint8List? captured;
    final recovery = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async => null,
        fetchSeedEnvelope: (_) async => null,
        isNetworkConfigured: () async => false,
      ),
    );
    final wallet = await bootWallet();
    await pumpSecurity(tester, wallet, recoveryService: recovery);

    await tester.enterText(
      find.byKey(const Key('security_export_pass_field')),
      'backup-passphrase',
    );
    await tester.tap(find.byKey(const Key('security_export_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    captured = wallet.exportEncryptedBackup('backup-passphrase');
    expect(captured, isNotNull);
    expect(captured!.isNotEmpty, isTrue);
  });

  testWidgets('Security tab restore button round-trips backup on blank store', (
    tester,
  ) async {
    final wallet = await bootWallet();
    final ledger = PercLedgerHub.instance.ledger;
    final balanceBefore = ledger.account('secuser')!.balance.microUnits;
    final scenarioBefore = ledger.account('secuser')!.scenarioBlockHeight;
    final exported = wallet.exportEncryptedBackup('backup-passphrase');

    PercLedgerHub.resetForTest();
    final blank = PercWalletProvider(store: PercWalletStoreMemory());
    await blank.initialize();

    final recovery = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async => exported,
        fetchSeedEnvelope: (_) async => null,
        isNetworkConfigured: () async => false,
      ),
    );
    await pumpSecurity(tester, blank, recoveryService: recovery);

    await tester.enterText(
      find.byKey(const Key('security_restore_pass_field')),
      'backup-passphrase',
    );
    await tester.tap(find.byKey(const Key('security_restore_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

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
    expect(blank.statusMessage, 'wallet_status_backup_restored');
  });
}