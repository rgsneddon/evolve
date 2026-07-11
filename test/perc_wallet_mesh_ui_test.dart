import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/widgets/wallet_mesh_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    PercNetworkCoordinator.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  testWidgets('mesh card renders sync status without peer wallet names', (
    tester,
  ) async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('dave', 'password12345');
    await wallet.register('erin', 'password12345');
    await wallet.login('dave', 'password12345');

    final strings = AppLocalizations.of(LocaleConfig.defaults);

    await tester.pumpWidget(
      ChangeNotifierProvider<PercWalletProvider>.value(
        value: wallet,
        child: MaterialApp(
          home: Scaffold(
            body: WalletMeshCard(wallet: wallet, strings: strings),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(strings.t('wallet_mesh_title')), findsOneWidget);
    expect(
      find.textContaining(
        strings
            .t('wallet_mesh_connected')
            .replaceAll('{count}', '${wallet.connectedWalletCount}'),
      ),
      findsOneWidget,
    );

    expect(find.textContaining('Peers:'), findsNothing);
    expect(find.textContaining('Pares:'), findsNothing);
    expect(find.text('erin'), findsNothing);
    expect(find.text(PercChainConstants.treasuryUsername), findsNothing);

    expect(find.byType(WalletMeshCard), findsOneWidget);
  });
}