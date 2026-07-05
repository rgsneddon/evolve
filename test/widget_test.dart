import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/main.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/screens/app_bootstrap_screen.dart';
import 'package:evolve/screens/evolve_loading_screen.dart';
import 'package:evolve/widgets/evolve_banner.dart';

Future<void> _unlockApp(PercWalletProvider wallet) async {
  await wallet.initialize();
  await wallet.setupTreasuryPassword('password12345');
  await wallet.register('widgetuser', 'password12345');
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

  testWidgets('app loads with both analysis modes', (tester) async {
    EvolveLoadingScreen.durationOverride = Duration.zero;
    AppBootstrapScreen.minSplashDurationOverride = Duration.zero;
    addTearDown(() {
      EvolveLoadingScreen.durationOverride = null;
      AppBootstrapScreen.minSplashDurationOverride = null;
    });

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await provider.initialize();
    await fcg.initialize();
    await _unlockApp(wallet);

    await tester.pumpWidget(
      EvolveApp(
        evolveProvider: provider,
        walletProvider: wallet,
        fcgProvider: fcg,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

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
    EvolveLoadingScreen.durationOverride = Duration.zero;
    AppBootstrapScreen.minSplashDurationOverride = Duration.zero;
    addTearDown(() {
      EvolveLoadingScreen.durationOverride = null;
      AppBootstrapScreen.minSplashDurationOverride = null;
    });

    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await provider.initialize();
    await fcg.initialize();
    await wallet.initialize();

    await tester.pumpWidget(
      EvolveApp(
        evolveProvider: provider,
        walletProvider: wallet,
        fcgProvider: fcg,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Create your wallet'), findsOneWidget);
    expect(find.text('YOUR SCENARIO'), findsNothing);
  });
}