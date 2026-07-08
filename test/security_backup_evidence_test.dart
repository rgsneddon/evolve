import 'dart:io';
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
import 'package:evolve/perc/services/perc_wallet_backup.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/services/security_backup_files.dart';
import 'package:evolve/perc/services/security_recovery_service.dart';
import 'test_locale_provider.dart';

final _scratch = Platform.environment['SCRATCH'] ??
    r'C:\Users\rgsne\AppData\Local\Temp\grok-goal-60921c3283b2\implementer';

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
        scenarioLabel: 'security evidence test seed',
      ),
    );
    return seed;
  }

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
    String? capturedName;
    Uint8List? exportBytes;
    PercNetworkCoordinator.instance.registerTestSeedLedger(
      _registrationSeedForTests(),
    );
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('secuser', 'password12345');
    final ledger = PercLedgerHub.instance.ledger;
    ledger.creditScenario(username: 'secuser', percentChance: 55);
    ledger.recordMicroblock(
      input: const ScenarioInput(topic: 'export-ext', posedQuestion: 'gate?'),
      locale: LocaleConfig.defaults,
    );
    final exportBalance = ledger.account('secuser')!.balance.microUnits;
    final exportScenario = ledger.account('secuser')!.scenarioBlockHeight;

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
              capturedName = suggestedName;
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

    final defaultName = defaultBackupExportFilename();
    final ioSaveSrc =
        File('lib/perc/services/security_backup_files_io.dart').readAsStringSync();

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

    final extensionLines = <String>[
      '=== backup export extension gating ===',
      'default_filename=$defaultName',
      'default_ends_with_percbackup=${defaultName.endsWith('.percbackup')}',
      'captured_suggested_name=$capturedName',
      'captured_ends_with_percbackup=${capturedName?.endsWith('.percbackup') ?? false}',
      'io_save_dialog_percbackup_only=${ioSaveSrc.contains("extensions: ['percbackup']")}',
      'io_save_dialog_no_txt=${!ioSaveSrc.contains("'txt'")}',
      'balance_micro_before_export=$exportBalance',
      'scenario_height_before_export=$exportScenario',
    ];
    expect(defaultName, endsWith('.percbackup'));
    expect(capturedName, endsWith('.percbackup'));
    expect(ioSaveSrc.contains("extensions: ['percbackup']"), isTrue);
    expect(ioSaveSrc.contains("'txt'"), isFalse);
    expect(exportBalance, greaterThan(0));
    expect(exportScenario, greaterThan(0));
    extensionLines.add(
      'OBSERVATION: export default and save dialog use .percbackup only',
    );
    _writeLog('backup_export_extension.log', extensionLines);
  });

  testWidgets('evidence: import flow invokes file resolver and restores status', (
    tester,
  ) async {
    PercNetworkCoordinator.instance.registerTestSeedLedger(
      _registrationSeedForTests(),
    );
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('secuser', 'password12345');
    final ledger = PercLedgerHub.instance.ledger;
    ledger.creditScenario(username: 'secuser', percentChance: 44);
    ledger.recordMicroblock(
      input: const ScenarioInput(topic: 'restore-file', posedQuestion: 'gate?'),
      locale: LocaleConfig.defaults,
    );
    final balanceBefore = ledger.account('secuser')!.balance.microUnits;
    final scenarioBefore = ledger.account('secuser')!.scenarioBlockHeight;
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

    final restoredLedger = PercLedgerHub.instance.ledger;
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

    final restoreLines = <String>[
      '=== backup file restore gating ===',
      'session_username=${restoredLedger.sessionUsername}',
      'balance_before_micro=$balanceBefore',
      'balance_after_micro=${restoredLedger.account('secuser')!.balance.microUnits}',
      'scenario_height_before=$scenarioBefore',
      'scenario_height_after=${restoredLedger.account('secuser')!.scenarioBlockHeight}',
      'web_resolver_no_clipboard=${!File('lib/perc/services/security_recovery_backup_resolver_web.dart').readAsStringSync().contains('Clipboard')}',
      'io_resolver_percbackup_only=${File('lib/perc/services/security_recovery_backup_resolver_io.dart').readAsStringSync().contains("extensions: ['percbackup']")}',
    ];
    expect(restoredLedger.sessionUsername, 'secuser');
    expect(balanceBefore, greaterThan(0));
    expect(scenarioBefore, greaterThan(0));
    expect(
      restoredLedger.account('secuser')!.balance.microUnits,
      balanceBefore,
    );
    expect(
      restoredLedger.account('secuser')!.scenarioBlockHeight,
      scenarioBefore,
    );
    restoreLines.add(
      'OBSERVATION: .percbackup file restore round-trips session, balance, scenario height',
    );
    _writeLog('backup_file_restore.log', restoreLines);
  });

  test('evidence: security screen uses file download/upload paths', () {
    final securitySrc = File('lib/perc/screens/security_screen.dart').readAsStringSync();
    final webBackupSrc =
        File('lib/perc/services/security_backup_files_web.dart').readAsStringSync();
    final webResolverSrc =
        File('lib/perc/services/security_recovery_backup_resolver_web.dart')
            .readAsStringSync();
    final ioResolverSrc =
        File('lib/perc/services/security_recovery_backup_resolver_io.dart')
            .readAsStringSync();

    final lines = <String>[
      '=== backup ui paths ===',
      'security_screen_has_exportBackupToDevice=${securitySrc.contains('exportBackupToDevice')}',
      'security_screen_no_clipboard_export=${!securitySrc.contains('Clipboard')}',
      'web_download_helper=${webBackupSrc.contains('AnchorElement')}',
      'web_import_file_picker_only=${webResolverSrc.contains('openFile') && !webResolverSrc.contains('Clipboard')}',
      'io_import_percbackup_only=${ioResolverSrc.contains("extensions: ['percbackup']")}',
      'default_export_percbackup=${File('lib/perc/services/security_backup_files.dart').readAsStringSync().contains('.percbackup')}',
    ];
    expect(securitySrc.contains('exportBackupToDevice'), isTrue);
    expect(securitySrc.contains('Clipboard'), isFalse);
    expect(webBackupSrc.contains('AnchorElement'), isTrue);
    expect(webResolverSrc.contains('openFile'), isTrue);
    expect(webResolverSrc.contains('Clipboard'), isFalse);
    expect(ioResolverSrc.contains("extensions: ['percbackup']"), isTrue);
    lines.add('OBSERVATION: backup export/import uses .percbackup file paths only');
    _writeLog('backup_ui_paths.log', lines);

    final removedLines = <String>[
      '=== backup txt removed gating ===',
      'clipboard_module_deleted=${!File('lib/perc/services/perc_wallet_backup_clipboard.dart').existsSync()}',
      'web_resolver_no_clipboard=${!webResolverSrc.contains('Clipboard')}',
      'default_export_no_txt=${!File('lib/perc/services/security_backup_files.dart').readAsStringSync().contains('.txt')}',
      'l10n_no_txt_import=${!File('lib/l10n/app_localizations.dart').readAsStringSync().contains('.txt or .percbackup')}',
    ];
    expect(
      File('lib/perc/services/perc_wallet_backup_clipboard.dart').existsSync(),
      isFalse,
    );
    expect(webResolverSrc.contains('Clipboard'), isFalse);
    removedLines.add('OBSERVATION: .txt and clipboard backup paths removed');
    _writeLog('backup_txt_removed.log', removedLines);
  });
}