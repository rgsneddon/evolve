import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/perc/screens/wallet_screen.dart';
import 'package:evolve/screens/evolve_shell_screen.dart';
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
        scenarioLabel: 'security nav test seed',
      ),
    );
    return seed;
  }

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Security nav sits between Wallet and Credit when gated',
      (tester) async {
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
    expect(labels, isNot(contains('VPN')));
  });

  testWidgets('full app access nav has no VPN destination', (tester) async {
    PercNetworkCoordinator.instance.registerTestSeedLedger(
      _registrationSeedForTests(),
    );
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

    expect(labels, contains('Analysis'));
    expect(labels, contains('Wallet'));
    expect(labels, contains('Security'));
    expect(labels, contains('Voting'));
    expect(labels, contains('Credit'));
    expect(labels, isNot(contains('VPN')));
    expect(labels.indexOf('Wallet'), lessThan(labels.indexOf('Security')));
    expect(labels.indexOf('Security'), lessThan(labels.indexOf('Credit')));
    expect(labels.last, 'Credit');
  });

  testWidgets('logout from Wallet tab returns to wallet login, not Security',
      (tester) async {
    PercNetworkCoordinator.instance.registerTestSeedLedger(
      _registrationSeedForTests(),
    );
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('navuser', 'password12345');
    expect(wallet.hasAppAccess, isTrue);
    await pumpShell(tester, wallet);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(wallet.hasAppAccess, isFalse);
    expect(find.text('Evolve Wallet sign-in'), findsOneWidget);
    expect(find.byType(WalletScreen), findsOneWidget);

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);
  });
}