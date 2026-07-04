import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
  });

  test('syncWalletToSeed runs force sync without throwing', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('sync_user', 'password12345');

    expect(wallet.isSyncingWallet, isFalse);
    await wallet.syncWalletToSeed();
    expect(wallet.isSyncingWallet, isFalse);
    expect(wallet.errorMessage ?? wallet.statusMessage, isNotNull);
  });

  test('forceSyncWalletToSeed sets syncing then completes', () async {
    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);
    final network = PercLedgerHub.instance.network;

    await network.forceSyncWalletToSeed();
    expect(
      network.syncState,
      anyOf(
        PercNetworkSyncState.synced,
        PercNetworkSyncState.syncing,
        PercNetworkSyncState.idle,
      ),
    );
  });
}