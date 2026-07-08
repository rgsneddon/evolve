import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('resolveAdvertisedEndpoint falls back when node server has no endpoint', () async {
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    final coordinator = PercNetworkCoordinator.instance;
    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);

    final endpoint = await coordinator.resolveAdvertisedEndpointForTest();
    expect(endpoint, isNotNull);
    expect(endpoint, isNotEmpty);
    expect(
      endpoint!.contains('127.0.0.1') ||
          endpoint.contains('onrender.com') ||
          endpoint.startsWith('http'),
      isTrue,
    );

    PercNetworkCoordinator.disableLiveNodesForTests = true;
  });

  test('send uses force sync before resolving recipient', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('sender', 'password12345');
    PercLedgerHub.instance.ledger.launchBlockchain();
    await wallet.creditScenario(outcomeScore: 50, memo: 'fund');

    final bobAddr = PercLedgerHub.instance.ledger.account('sender')!.address;
    await wallet.send(toAddress: bobAddr, amountText: '0.00000001');
    expect(wallet.errorMessage, 'wallet_err_send_to_yourself');
  });
}