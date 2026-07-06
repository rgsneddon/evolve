import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/main.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'test_locale_provider.dart';
import 'package:evolve/screens/evolve_loading_screen.dart';
import 'package:evolve/widgets/evolve_banner.dart';


Future<void> _unlockApp(PercWalletProvider wallet) async {
  await wallet.initialize();
  await wallet.setupTreasuryPassword('password12345');
  await wallet.register('widgetuser', 'password12345');
}

Future<void> _enterFromSplash(WidgetTester tester) async {
  if (find.text('Enter Evolve').evaluate().isNotEmpty) {
    await tester.tap(find.text('Enter Evolve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    EvolveLoadingScreen.introDurationOverride = Duration.zero;
  });
  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    EvolveLoadingScreen.introDurationOverride = null;
  });

  testWidgets('app loads with both analysis modes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await provider.initialize();
    await fcg.initialize();
    final locale = await createTestLocaleProvider();
    await _unlockApp(wallet);

    await tester.pumpWidget(
      EvolveApp(
        evolveProvider: provider,
        walletProvider: wallet,
        fcgProvider: fcg,
        localeProvider: locale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _enterFromSplash(tester);

    expect(find.text('Evolve'), findsOneWidget);
    expect(find.byType(EvolveBanner), findsOneWidget);
    expect(find.textContaining('SELECT THE REGION OR COUNTRY'), findsOneWidget);
    expect(find.text('YOUR SCENARIO'), findsOneWidget);
    expect(find.text('RESULTS'), findsOneWidget);
    expect(find.text('POSE YOUR QUESTION HERE (optional)'), findsOneWidget);
    expect(find.text('RUN ANALYSIS'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(2));
  });

  testWidgets('unsigned user lands on wallet registration after splash', (tester) async {
    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await provider.initialize();
    await fcg.initialize();
    final locale = await createTestLocaleProvider();

    await tester.pumpWidget(
      EvolveApp(
        evolveProvider: provider,
        walletProvider: wallet,
        fcgProvider: fcg,
        localeProvider: locale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Create your wallet first'), findsOneWidget);
    expect(find.text('YOUR SCENARIO'), findsNothing);
  });
}