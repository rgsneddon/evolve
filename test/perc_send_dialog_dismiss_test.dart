import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_send_receive_actions.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/models/locale_config.dart';

Future<PercWalletProvider> _fundedSender() async {
  final wallet = PercWalletProvider(store: PercWalletStoreMemory());
  await wallet.initialize();
  await wallet.setupTreasuryPassword('password12345');
  await wallet.register('alice', 'password12345');
  PercLedgerHub.instance.ledger.launchBlockchain();
  final credit = await wallet.creditScenario(outcomeScore: 80, memo: 'fund');
  expect(credit?.status, PercFaucetCreditStatus.credited);
  return wallet;
}

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercLedgerHub.resetForTest();
  });

  testWidgets('showSend dismisses dialog on confirm and surfaces send status', (
    tester,
  ) async {
    final wallet = await _fundedSender();
    PercLedgerHub.instance.ledger.register('bob', 'password12345');
    final bobAddr = PercLedgerHub.instance.ledger.account('bob')!.address;

    final strings = AppLocalizations.of(LocaleConfig.defaults);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => PercSendReceiveActions.showSend(
                context,
                wallet: wallet,
                strings: strings,
              ),
              child: const Text('Open Send'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Send'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), bobAddr);
    await tester.enterText(fields.at(1), '0.00000001');

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, strings.t('wallet_send_confirm')),
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text(strings.t('wallet_send_auth_title')), findsOneWidget);
    final authFields = find.byType(TextField);
    await tester.enterText(authFields.last, 'password12345');
    final authorize = find.widgetWithText(
      FilledButton,
      strings.t('wallet_send_auth_confirm'),
    );
    await tester.tap(authorize);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AlertDialog), findsNothing);

    for (var i = 0; i < 30 && wallet.statusMessage == null && wallet.errorMessage == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(wallet.statusMessage, isNotNull);
    expect(wallet.errorMessage, isNull);
    expect(wallet.statusMessage, startsWith('wallet_status_sent'));

    // Clear ephemeral status timer so the test binding stays clean.
    await tester.pump(const Duration(seconds: 16));
  });

  testWidgets('showSend dismisses dialog even when validation fails', (
    tester,
  ) async {
    final wallet = await _fundedSender();
    final strings = AppLocalizations.of(LocaleConfig.defaults);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => PercSendReceiveActions.showSend(
                context,
                wallet: wallet,
                strings: strings,
              ),
              child: const Text('Open Send'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Send'));
    await tester.pumpAndSettle();

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, strings.t('wallet_send_confirm')),
    );
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AlertDialog), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));

    expect(wallet.errorMessage, isNotNull);
    expect(wallet.statusMessage, isNull);
  });
}