import 'dart:io';

import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/screens/wallet_screen.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/widgets/wallet_auth_panel.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'test_locale_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    PercLedgerHub.resetForTest();
  });

  Future<void> pumpWalletScreen(WidgetTester tester, PercWalletProvider wallet) async {
    final locale = await createTestLocaleProvider();
    final evolve = EvolveProvider();
    await evolve.initialize();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: locale),
          ChangeNotifierProvider.value(value: evolve),
        ],
        child: const MaterialApp(home: WalletScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('unsigned WalletScreen login hides treasury emission banner',
      (tester) async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');
    await wallet.logout();
    await pumpWalletScreen(tester, wallet);

    expect(find.text('Evolve Wallet sign-in'), findsOneWidget);
    expect(find.text('Treasury emission'), findsNothing);
  });

  testWidgets('splash WalletAuthPanel hides treasury emission above sign-in',
      (tester) async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    final locale = await createTestLocaleProvider();
    final evolve = EvolveProvider();
    await evolve.initialize();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: locale),
          ChangeNotifierProvider.value(value: evolve),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WalletAuthPanel(
                compact: true,
                showCreatorCredit: false,
                autoPromptBiometricOnLaunch: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Treasury emission'), findsNothing);
  });

  test('signed-in wallet home retains treasury emission card wiring', () {
    final source =
        File('lib/perc/screens/wallet_screen.dart').readAsStringSync();
    final loginStart = source.indexOf('Widget _loginRegister');
    final loginEnd = source.indexOf('Widget _walletHome', loginStart);
    expect(loginStart, greaterThan(0));
    expect(loginEnd, greaterThan(loginStart));
    final loginBlock = source.substring(loginStart, loginEnd);
    expect(loginBlock, isNot(contains('_publicTreasuryBanner')));
    expect(source, contains('Widget _treasuryCard'));
    expect(source, contains("strings.t('wallet_treasury_title')"));
  });
}