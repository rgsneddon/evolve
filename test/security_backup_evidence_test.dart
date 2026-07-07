import 'dart:io';
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
import 'package:evolve/perc/services/perc_wallet_backup.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/services/security_recovery_service.dart';
import 'test_locale_provider.dart';

final _scratch = r'C:\Users\rgsne\AppData\Local\Temp\grok-goal-48ffdf7205d8\implementer';

void _writeLog(String name, List<String> lines) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch\\$name').writeAsStringSync(lines.join('\n'));
}

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('evidence: backup roundtrip preserves session balances and scenario height', () async {
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
    final lines = <String>[
      '=== backup roundtrip probe ===',
      'session_before=dave',
      'session_after=${after.sessionUsername}',
      'balance_before_micro=$beforeBalance',
      'balance_after_micro=${after.account('dave')!.balance.microUnits}',
      'scenario_height_before=$beforeScenario',
      'scenario_height_after=${after.account('dave')!.scenarioBlockHeight}',
    ];
    expect(after.sessionUsername, 'dave');
    expect(after.account('dave')!.balance.microUnits, beforeBalance);
    expect(after.account('dave')!.scenarioBlockHeight, beforeScenario);
    lines.add('OBSERVATION: round-trip preserved session, balance, scenario height');
    _writeLog('backup_roundtrip_probe.log', lines);
  });

  testWidgets('evidence: export flow uses download port not clipboard', (
    tester,
  ) async {
    var exportInvoked = false;
    Uint8List? exportBytes;
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('secuser', 'password12345');

    final locale = await createTestLocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          home: SecurityScreen(
            exportBackupFile: ({
              required String suggestedName,
              required Uint8List bytes,
            }) async {
              exportInvoked = true;
              exportBytes = bytes;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('security_export_pass_field')),
      'backup-passphrase',
    );
    await tester.tap(find.byKey(const Key('security_export_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final lines = <String>[
      '=== backup export flow ===',
      'export_port_invoked=$exportInvoked',
      'export_bytes_nonempty=${exportBytes?.isNotEmpty ?? false}',
      'clipboard_only_web=false',
    ];
    expect(exportInvoked, isTrue);
    expect(exportBytes, isNotNull);
    expect(exportBytes!.isNotEmpty, isTrue);
    lines.add('OBSERVATION: export tapped save/download port with encrypted bytes');
    _writeLog('backup_export_flow.log', lines);
  });

  testWidgets('evidence: import flow invokes file resolver and restores status', (
    tester,
  ) async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('secuser', 'password12345');
    final exported = wallet.exportEncryptedBackup('backup-passphrase');
    var pickerInvoked = false;

    PercLedgerHub.resetForTest();
    final blank = PercWalletProvider(store: PercWalletStoreMemory());
    await blank.initialize();

    final recovery = SecurityRecoveryService(
      ports: SecurityRecoveryPorts(
        resolveBackupBytes: () async {
          pickerInvoked = true;
          return exported;
        },
        fetchSeedEnvelope: (_) async => null,
        isNetworkConfigured: () async => false,
      ),
    );

    final locale = await createTestLocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: blank),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          home: SecurityScreen(recoveryService: recovery),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('security_restore_pass_field')),
      'backup-passphrase',
    );
    await tester.tap(find.byKey(const Key('security_restore_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final lines = <String>[
      '=== backup import flow ===',
      'file_picker_port_invoked=$pickerInvoked',
      'status_message=${blank.statusMessage}',
      'is_logged_in=${blank.isLoggedIn}',
    ];
    expect(pickerInvoked, isTrue);
    expect(blank.statusMessage, 'wallet_status_backup_restored');
    expect(blank.isLoggedIn, isTrue);
    lines.add('OBSERVATION: import used file resolver and restored wallet session');
    _writeLog('backup_import_flow.log', lines);
  });

  test('evidence: security screen uses file download/upload paths', () {
    final securitySrc = File('lib/perc/screens/security_screen.dart').readAsStringSync();
    final webBackupSrc =
        File('lib/perc/services/security_backup_files_web.dart').readAsStringSync();
    final webResolverSrc =
        File('lib/perc/services/security_recovery_backup_resolver_web.dart')
            .readAsStringSync();

    final lines = <String>[
      '=== backup ui paths ===',
      'security_screen_has_exportBackupToDevice=${securitySrc.contains('exportBackupToDevice')}',
      'security_screen_no_web_clipboard_export=${!securitySrc.contains('Clipboard.setData')}',
      'web_download_helper=${webBackupSrc.contains('AnchorElement')}',
      'web_import_file_picker_first=${webResolverSrc.indexOf('openFile') < webResolverSrc.indexOf('Clipboard')}',
    ];
    expect(securitySrc.contains('exportBackupToDevice'), isTrue);
    expect(securitySrc.contains('Clipboard.setData'), isFalse);
    expect(webBackupSrc.contains('AnchorElement'), isTrue);
    expect(
      webResolverSrc.indexOf('openFile'),
      lessThan(webResolverSrc.indexOf('Clipboard')),
    );
    lines.add('OBSERVATION: web export downloads; web import prefers file picker');
    _writeLog('backup_ui_paths.log', lines);
  });
}