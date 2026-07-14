import 'package:evolve_tunnel/evolve_tunnel.dart';
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
import 'package:evolve/screens/evolve_shell_screen.dart';
import 'mock_tunnel.dart';
import 'test_locale_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  EvolveTunnelController? _lastTunnel;

  tearDown(() {
    _lastTunnel?.stopStatusPolling();
    _lastTunnel = null;
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
        scenarioLabel: 'vpn nav test seed',
      ),
    );
    return seed;
  }

  Future<void> pumpShell(
    WidgetTester tester,
    PercWalletProvider wallet,
    EvolveTunnelController tunnel,
  ) async {
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
          ChangeNotifierProvider.value(value: tunnel),
        ],
        child: MaterialApp(
          home: const EvolveShellScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('VPN nav is second from the right when wallet has app access',
      (tester) async {
    PercNetworkCoordinator.instance.registerTestSeedLedger(
      _registrationSeedForTests(),
    );
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('vpnnavuser', 'password12345');
    expect(wallet.hasAppAccess, isTrue);

    final tunnel = createMockTunnelController();
    _lastTunnel = tunnel;
    await pumpShell(tester, wallet, tunnel);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();

    expect(labels.length, greaterThanOrEqualTo(2));
    expect(labels[labels.length - 1], 'Credit');
    expect(labels[labels.length - 2], 'VPN');
    tunnel.stopStatusPolling();
  });

  testWidgets('VPN screen exposes connect and disconnect controls', (tester) async {
    PercNetworkCoordinator.instance.registerTestSeedLedger(
      _registrationSeedForTests(),
    );
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('treasury-pass-phrase');
    await wallet.register('vpnctrluser', 'password12345');

    final tunnel = createMockTunnelController();
    _lastTunnel = tunnel;
    tunnel.updateWalletAccess(true);
    await pumpShell(tester, wallet, tunnel);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    final vpnIndex = labels.indexOf('VPN');
    expect(vpnIndex, greaterThanOrEqualTo(0));

    await tester.tap(find.byType(NavigationDestination).at(vpnIndex));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(
      find.textContaining('internet may be slow to start'),
      findsOneWidget,
    );
    tunnel.stopStatusPolling();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}