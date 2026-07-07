import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/widgets/registration_seed_setup_dialog.dart';
import 'test_locale_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  Future<PercWalletProvider> pendingWallet() async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('newuser', 'password12345');
    expect(wallet.pendingSeedSetup, isTrue);
    expect(wallet.isWalletConnectComplete, isFalse);
    return wallet;
  }

  testWidgets('registration seed dialog offers generate and skip', (tester) async {
    final wallet = await pendingWallet();
    final locale = await createTestLocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          home: RegistrationSeedSetupDialogHost(
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Optional 12-word recovery seed'), findsOneWidget);
    expect(find.textContaining('only have one opportunity'), findsOneWidget);
    expect(find.byKey(const Key('registration_seed_generate_button')), findsOneWidget);
    expect(find.byKey(const Key('registration_seed_skip_button')), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('registration_seed_skip_button')),
    );
    await tester.tap(find.byKey(const Key('registration_seed_skip_button')));
    await tester.pumpAndSettle();

    expect(wallet.pendingSeedSetup, isFalse);
    expect(wallet.isWalletConnectComplete, isTrue);
    await wallet.logout();
  });

  testWidgets('generate fills twelve boxes without selectable copy text', (tester) async {
    final wallet = await pendingWallet();
    final locale = await createTestLocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: const MaterialApp(
          home: RegistrationSeedSetupDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('registration_seed_generate_button')),
    );
    await tester.tap(find.byKey(const Key('registration_seed_generate_button')));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNothing);
    expect(find.byKey(const Key('registration_seed_confirm_saved_button')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('registration_seed_confirm_saved_button')),
    );
    await tester.tap(find.byKey(const Key('registration_seed_confirm_saved_button')));
    await tester.pumpAndSettle();

    expect(wallet.pendingSeedSetup, isFalse);
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(
      PercLedgerHub.instance.ledger.account('newuser')!.seedFingerprint,
      isNotNull,
    );
    await wallet.logout();
  });
}