import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('fresh seed peer status is online within peer window', () {
    final status = PercNetworkStatus(
      evolutionaryChainId: PercChainConstants.evolutionaryChainId,
      blockHeight: 1,
      tipHash: 'tip',
      revision: 1,
      sessionUsername: 'alice',
      updatedAt: DateTime.now().toUtc(),
    );
    expect(status.isFreshOnSeedPeer, isTrue);
  });

  test('stale seed peer status is offline for instant delivery', () {
    final status = PercNetworkStatus(
      evolutionaryChainId: PercChainConstants.evolutionaryChainId,
      blockHeight: 1,
      tipHash: 'tip',
      revision: 1,
      sessionUsername: 'alice',
      updatedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
    );
    expect(status.isFreshOnSeedPeer, isFalse);
  });

  test('deliverInstantly false queues until receiver advances scenario block', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000010),
      deliverInstantly: false,
    );

    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.pendingInboundFor('bob'), hasLength(1));

    ledger.login('bob', 'password123');
    expect(ledger.account('bob')!.balance, PercAmount.fromPerc(0.00000010));
    expect(ledger.pendingInboundFor('bob'), isEmpty);
  });

  test('deliverInstantly true credits signed-in recipient on inbound refresh', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);
    ledger.login('bob', 'password123');
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000005),
      deliverInstantly: true,
    );

    ledger.refreshPendingInboundForSession();
    expect(ledger.pendingInboundFor('bob'), isEmpty);
    expect(
      ledger.account('bob')!.balance,
      PercAmount.fromPerc(0.00000005),
    );
  });

  test('deliverInstantly true queues for cross-device receiver sync', () {
    final sender = PercLedger.empty();
    _seedLedger(sender);
    sender.register('alice', 'password123');
    sender.register('bob', 'password123');
    sender.creditScenario(username: 'alice', percentChance: 50);
    sender.login('alice', 'password123');

    sender.send(
      fromUsername: 'alice',
      toAddress: _addr(sender, 'bob'),
      amount: PercAmount.fromPerc(0.00000005),
      deliverInstantly: true,
    );

    expect(sender.pendingInboundFor('bob'), hasLength(1));
    expect(sender.account('bob')!.balance, PercAmount.zero);

    final receiver = PercLedger.fromJson(sender.toJson());
    receiver.login('bob', 'password123');

    receiver.refreshPendingInboundForSession();
    expect(receiver.pendingInboundFor('bob'), isEmpty);
    expect(
      receiver.account('bob')!.balance,
      PercAmount.fromPerc(0.00000005),
    );
    expect(receiver.account('bob')!.transactions, isNotEmpty);
  });

  test('updatePeerFromStatus uses seed heartbeat for online flag', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);

    ledger.updatePeerFromStatus(
      PercNetworkStatus(
        evolutionaryChainId: PercChainConstants.evolutionaryChainId,
        blockHeight: PercChainTip.height(ledger),
        tipHash: PercChainTip.hash(ledger),
        revision: 1,
        sessionUsername: 'bob',
        walletAddress: 'percpriv1bob',
        updatedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 9)),
      ),
    );

    expect(ledger.isWalletOnlineOnNetwork('bob'), isFalse);
  });
}