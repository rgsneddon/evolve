import 'dart:io';

import 'package:evolve/fcg/mishi/fcg_mishi_bridge_store.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/screens/fcg_voting_screen.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'test_locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercLedgerHub.resetForTest();
  });

  testWidgets(
    'FcgVotingScreen shows blocked card for non-approved voter with moderator consult copy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late Directory tempDir;
      late PercWalletProvider wallet;
      late FcgVotingProvider fcg;
      late LocaleProvider locale;

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('fcg-blocked-ui-');
        final store = PercWalletStoreMemory();
        final ledger = PercLedger.empty();
        ledger.ensureTreasuryAccount();
        ledger.setupTreasuryPassword('password12345');
        ledger.launchBlockchain();
        ledger.consumeBlockchainLaunchEvent();
        ledger.register('parishvoter', 'password12345');
        ledger.login('parishvoter', 'password12345');
        await store.save(ledger);
        await PercLedgerHub.instance.loadStoreForTest(store);

        wallet = PercWalletProvider(store: store);
        final bridge = FcgMishiBridgeStore(
          fileResolver: () => FcgMishiBridgeStore.fileForTest(tempDir.path),
        );
        fcg = FcgVotingProvider(
          store: FcgStoreMemory(),
          mishiBridge: bridge,
        );
        await fcg.initialize();
        locale = await createTestLocaleProvider();

        await fcg.refreshVotingAccess(
          walletAddress: PercLedgerHub.instance.ledger.sessionAccount?.address,
          walletUsername: 'parishvoter',
          regionId: locale.config.regionId,
          locale: locale.config,
        );
        expect(fcg.votingAccessApproved, isFalse);
      });

      addTearDown(() async {
        wallet.dispose();
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: locale),
            ChangeNotifierProvider<PercWalletProvider>.value(value: wallet),
            ChangeNotifierProvider<FcgVotingProvider>.value(value: fcg),
          ],
          child: const MaterialApp(
            home: FcgVotingScreen(skipInitialAccessRefresh: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Card), findsWidgets);
      expect(
        find.text('Voting access requires moderator approval'),
        findsOneWidget,
      );
      expect(find.textContaining('Parish voting is gated'), findsOneWidget);
      expect(find.textContaining('Consult your ward moderator'), findsOneWidget);
      expect(find.textContaining('monthly forum'), findsOneWidget);
      expect(find.text('Request voting access'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
    },
  );
}