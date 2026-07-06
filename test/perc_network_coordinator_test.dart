import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_config.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_public_endpoint.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';

void _launchChainForTests() {
  PercLedgerHub.instance.ledger.launchBlockchain();
}

void main() {
  setUp(() {
    PercNetworkConfig.resetForTest();
    PercLedgerHub.resetForTest();
  });

  test('online wallet registers as network node at current block height', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');

    expect(wallet.onlineNetworkNodes.any((n) => n.username == 'alice' && n.online), isTrue);
    expect(wallet.blockHeight, wallet.networkBlockHeight);
    expect(wallet.isNetworkSynced, isTrue);
    expect(wallet.onlineNetworkNodes, isNotEmpty);
    expect(
      wallet.onlineNetworkNodes.any((n) => n.username == 'alice' && n.online),
      isTrue,
    );
  });

  test('all wallets on hub share the same block height', () async {
    final store = PercWalletStoreMemory();
    final walletA = PercWalletProvider(store: store);
    final walletB = PercWalletProvider(store: store);
    await walletA.initialize();
    await walletB.initialize();
    await walletA.setupTreasuryPassword('password12345');
    await walletA.register('bob', 'password12345');

    expect(walletB.blockHeight, walletA.blockHeight);
    expect(walletB.networkBlockHeight, walletA.networkBlockHeight);
  });

  test('importPeerLedger aligns local wallet to taller peer chain', () {
    final local = PercLedger.empty();
    local.ensureTreasuryAccount();
    local.setupTreasuryPassword('password12345');
    local.launchBlockchain();
    local.register('alice', 'password12345');

    final remote = PercLedger.fromJson(local.toJson());
    remote.creditScenario(
      username: 'alice',
      percentChance: 50,
      scenarioLabel: 'peer growth',
    );

    expect(remote.blockHeight, greaterThan(local.blockHeight));

    local.importPeerLedger(
      remote,
      expectedTipHash: PercChainTip.hash(remote),
    );

    expect(local.blockHeight, remote.blockHeight);
    expect(PercChainTip.hash(local), PercChainTip.hash(remote));
  });

  test('recipient delivery uses network online presence', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('sender', 'password12345');
    await wallet.logout();
    await wallet.register('receiver', 'password12345');

    final receiverAddr = wallet.addressForUsername('receiver');
    await wallet.logout();
    await wallet.login('sender', 'password12345');
    _launchChainForTests();
    await wallet.creditScenario(outcomeScore: 50, memo: 'fund sender');

    final receiverOnlineBefore = wallet.onlineNetworkNodes
        .any((n) => n.username == 'receiver' && n.online);
    expect(receiverOnlineBefore, isFalse);

    await wallet.send(
      toAddress: receiverAddr,
      amountText: '0.00000001',
    );

    final ledger = PercLedgerHub.instance.ledger;
    expect(
      ledger.pendingInboundFor('receiver'),
      isNotEmpty,
    );
  });

  test('stores internet endpoint on network node when advertised', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');

    final ledger = PercLedgerHub.instance.ledger;
    final treasuryNode =
        ledger.networkNodes[PercChainConstants.treasuryUsername];
    expect(treasuryNode, isNotNull);
    if (treasuryNode?.endpoint != null) {
      expect(
        PercPublicEndpoint.isInternetEndpoint(treasuryNode!.endpoint) ||
            treasuryNode.endpoint!.contains('127.0.0.1'),
        isTrue,
      );
    }
  });

  test('coordinator reports synced when local height matches network', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');

    final coordinator = PercNetworkCoordinator.instance;
    expect(coordinator.syncState, PercNetworkSyncState.synced);
    expect(coordinator.isSyncedToNetwork, isTrue);
  });
}