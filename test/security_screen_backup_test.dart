import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/screens/security_screen.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
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
    PercLedgerHub.resetForTest();
  });

  PercLedger _registrationSeedForTests() {
    final seed = PercLedger.empty();
    seed.ensureTreasuryAccount();
    seed.setupTreasuryPassword('password12345');
    seed.launchBlockchain();
    seed.consumeBlockchainLaunchEvent();
    seed.blocks.add(
      PercBlock(
        index: seed.blocks.length,
        timestamp: DateTime.utc(2026, 3, 1),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'security backup test seed',
      ),
    );
    return seed;
  }

  Future<PercWalletProvider> bootWallet() async {
    PercNetworkCoordinator.instance.registerTestSeedLedger(
      _registrationSeedForTests(),
    );
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
    BackupFileExporter? exportBackupFile,
  }) async {
    final locale = await createTestLocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          home: SecurityScreen(
            recoveryService: recoveryService,
            exportBackupFile: exportBackupFile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Security tab export invokes save/download port with encrypted bytes', (
    tester,
  ) async {
    String? capturedName;
    Uint8List? capturedBytes;
    final wallet = await bootWallet();
    await pumpSecurity(
      tester,
      wallet,
      exportBackupFile: ({
        required String suggestedName,
        required Uint8List bytes,
      }) async {
        capturedName = suggestedName;
        capturedBytes = bytes;
        return true;
      },
    );

    await tester.enterText(
      find.byKey(const Key('security_export_pass_field')),
      'backup-passphrase',
    );
    await tester.tap(find.byKey(const Key('security_export_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(capturedBytes, isNotNull);
    expect(capturedBytes!.isNotEmpty, isTrue);
    expect(capturedName, endsWith('.percbackup'));
    final roundTrip = wallet.exportEncryptedBackup('backup-passphrase');
    expect(roundTrip.isNotEmpty, isTrue);
  });

  testWidgets('Security tab import invokes file resolver and restores wallet', (
    tester,
  ) async {
    final wallet = await bootWallet();
    final ledger = PercLedgerHub.instance.ledger;
    final balanceBefore = ledger.account('secuser')!.balance.microUnits;
    final scenarioBefore = ledger.account('secuser')!.scenarioBlockHeight;
    final exported = wallet.exportEncryptedBackup('backup-passphrase');
    var resolverCalled = false;

    PercLedgerHub.resetForTest();
    final blank = PercWalletProvider(store: PercWalletStoreMemory());
    await blank.initialize();

    final recovery = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async {
          resolverCalled = true;
          return exported;
        },
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

    expect(resolverCalled, isTrue);
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