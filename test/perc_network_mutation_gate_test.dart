import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
  });

  test('requireSyncedForMutation blocks when local chain is behind network', () async {
    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);
    final coordinator = PercNetworkCoordinator.instance;

    coordinator.setNetworkBlockHeightForTest(12);
    coordinator.setSyncStateForTest(PercNetworkSyncState.syncing);

    expect(
      () => coordinator.requireSyncedForMutation(),
      throwsStateError,
    );
  });

  test('requireSyncedForMutation allows commits when local chain is ahead', () async {
    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);
    final coordinator = PercNetworkCoordinator.instance;
    final ledger = PercLedgerHub.instance.ledger;

    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.launchBlockchain();
    ledger.register('alice', 'password12345');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final localHeight = PercChainTip.height(ledger);
    coordinator.setNetworkBlockHeightForTest(localHeight - 1);
    coordinator.setSyncStateForTest(PercNetworkSyncState.syncing);

    expect(() => coordinator.requireSyncedForMutation(), returnsNormally);
  });
}