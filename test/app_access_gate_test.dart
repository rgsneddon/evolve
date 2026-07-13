import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/main.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'mock_tunnel.dart';
import 'test_locale_provider.dart';
import 'package:evolve/screens/evolve_loading_screen.dart';
import 'package:evolve/widgets/evolve_banner.dart';


Future<void> _unlockApp(PercWalletProvider wallet) async {
  await wallet.initialize();
  await wallet.setupTreasuryPassword('password12345');
  await wallet.register('appuser', 'password12345');
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

  testWidgets('app shows wallet gate until PERC address is registered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await provider.initialize();
    await fcg.initialize();
    final locale = await createTestLocaleProvider();
    final tunnel = createMockTunnelController();

    await tester.pumpWidget(
      EvolveApp(
        evolveProvider: provider,
        walletProvider: wallet,
        fcgProvider: fcg,
        localeProvider: locale,
        tunnelController: tunnel,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(wallet.hasAppAccess, isFalse);
    tunnel.stopStatusPolling();
    expect(find.text('Create your wallet first'), findsOneWidget);
    expect(find.byType(EvolveBanner), findsNothing);
    expect(find.text('RUN ANALYSIS'), findsNothing);
  });

  testWidgets('app unlocks analysis after registration generates address', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await provider.initialize();
    await fcg.initialize();
    final locale = await createTestLocaleProvider();
    final tunnel = createMockTunnelController();
    await _unlockApp(wallet);

    expect(wallet.hasAppAccess, isTrue);
    expect(wallet.address.startsWith('percpriv1'), isTrue);

    await tester.pumpWidget(
      EvolveApp(
        evolveProvider: provider,
        walletProvider: wallet,
        fcgProvider: fcg,
        localeProvider: locale,
        tunnelController: tunnel,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Enter Evolve'), findsNothing);
    expect(find.text('Wallet loading…'), findsNothing);
    expect(find.byType(EvolveBanner), findsOneWidget);
    expect(find.text('RUN ANALYSIS'), findsOneWidget);
    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
  });
}