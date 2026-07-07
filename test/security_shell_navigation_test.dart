import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/screens/evolve_shell_screen.dart';
import 'test_locale_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  Future<void> pumpShell(WidgetTester tester, PercWalletProvider wallet) async {
    final evolve = EvolveProvider();
    await evolve.initialize();
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await fcg.initialize();
    final locale = await createTestLocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: evolve),
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: fcg),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          home: const EvolveShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Security nav sits between Wallet and Credit when gated', (tester) async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await pumpShell(tester, wallet);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();

    expect(labels.indexOf('Wallet'), 0);
    expect(labels.indexOf('Security'), 1);
    expect(labels.indexOf('Credit'), 2);
  });

  testWidgets('Security nav order with full app access', (tester) async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('navuser', 'password12345');
    expect(wallet.hasAppAccess, isTrue);
    await pumpShell(tester, wallet);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();

    expect(labels.indexOf('Wallet'), lessThan(labels.indexOf('Security')));
    expect(labels.indexOf('Security'), lessThan(labels.indexOf('Credit')));
  });
}