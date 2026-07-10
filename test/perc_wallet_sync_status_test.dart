import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

PercLedger _seedAheadLedger() {
  final seed = PercLedger.empty();
  seed.ensureTreasuryAccount();
  seed.setupTreasuryPassword('password12345');
  seed.networkGenesisRevision = 2;
  seed.launchBlockchain();
  seed.consumeBlockchainLaunchEvent();
  for (var i = 0; i < 2; i++) {
    seed.blocks.add(
      PercBlock(
        index: seed.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'seed-ahead-$i',
      ),
    );
  }
  return seed;
}

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercNetworkCoordinator.instance.registerTestSeedLedger(_seedAheadLedger());
  });

  tearDown(() {
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('syncWalletToSeed does not report seed offline when height advances', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('syncuser', 'password12345');
    await wallet.login('syncuser', 'password12345');

    PercNetworkCoordinator.instance.setSeedConnectedForTest(false);
    PercNetworkCoordinator.instance.setSyncStateForTest(
      PercNetworkSyncState.syncing,
    );

    await wallet.syncWalletToSeed();

    expect(wallet.errorMessage, isNot('wallet_sync_seed_offline'));
    expect(PercLedgerHub.instance.network.isConnectedToSeed, isTrue);
    expect(
      wallet.statusMessage == 'wallet_sync_success' ||
          wallet.statusMessage == 'wallet_sync_partial',
      isTrue,
      reason:
          'status=${wallet.statusMessage} error=${wallet.errorMessage} '
          'synced=${PercLedgerHub.instance.network.isSyncedToNetwork}',
    );
  });
}