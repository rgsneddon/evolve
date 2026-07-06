import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/providers/locale_provider.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/widgets/lawful_frame_flow_shard_graph.dart';
import 'package:evolve/perc/screens/blockchain_explorer_screen.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

Future<PercWalletProvider> walletWithTransfer() async {
  final store = PercWalletStoreMemory();
  final ledger = PercLedger.empty();
  _seed(ledger);
  ledger.register('alice', 'password12345');
  ledger.register('bob', 'password12345');
  ledger.creditScenario(username: 'alice', percentChance: 80);
  ledger.login('bob', 'password12345');
  ledger.send(
    fromUsername: 'alice',
    toAddress: ledger.account('bob')!.address,
    amount: PercAmount.fromPerc(0.00000005),
    deliverInstantly: true,
  );
  await store.save(ledger);

  final wallet = PercWalletProvider(store: store);
  await wallet.initialize();
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

  testWidgets('lawful frame-flow split shows transfer lane entry', (tester) async {
    final wallet = await walletWithTransfer();
    final strings = AppLocalizations.of(LocaleConfig.defaults);

    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LawfulFrameFlowShardGraph(wallet: wallet, strings: strings),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('Main-chain transfer lane'),
      findsOneWidget,
    );
    expect(find.textContaining('Block #'), findsWidgets);
    expect(find.textContaining('0.00000005'), findsWidgets);
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<LawfulFrameFlowPainter>()
        .toList();
    expect(painters, isNotEmpty);
    expect(painters.first.transferMarkers, isNotEmpty);
    final markerAngles = LawfulFrameFlowShardGraph.transferMarkerAnglesForBlocks(
      wallet.blocks,
      wallet.microblocksPerBlock,
    );
    expect(markerAngles, painters.first.transferMarkers);
    // Graphic proof for frame_flow_transfer.log capture
    print(
      'GRAPHIC: LawfulFrameFlowPainter transferMarkers=${painters.first.transferMarkers} '
      'angles=$markerAngles microblocksPerBlock=${wallet.microblocksPerBlock}',
    );
  });

  testWidgets('block explorer history shows Manual tx label on transfer block',
      (tester) async {
    final wallet = await walletWithTransfer();

    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<PercWalletProvider>.value(value: wallet),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const BlockchainExplorerScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Manual tx'), findsWidgets);
    expect(find.textContaining('0.00000005'), findsWidgets);
  });
}