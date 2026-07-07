import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';

import 'support/two_device_harness.dart';

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

  test('pending transfer credits receiver only after scenario block advance', () {
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
    expect(
      ledger.account('bob')!.transactions.any((tx) => !tx.isConfirmed),
      isTrue,
    );

    ledger.login('bob', 'password123');
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.pendingInboundFor('bob'), hasLength(1));

    ledger.advanceScenarioBlock('bob');
    expect(ledger.account('bob')!.balance, PercAmount.fromPerc(0.00000010));
    expect(ledger.pendingInboundFor('bob'), isEmpty);
    expect(
      ledger.account('bob')!.transactions.any((tx) => tx.isConfirmed),
      isTrue,
    );
  });

  test('login alone does not credit queued inbound transfer', () {
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
    expect(ledger.pendingInboundFor('bob'), hasLength(1));
    expect(
      ledger.account('bob')!.balance,
      PercAmount.zero,
    );
  });

  test('cross-device receiver confirms after scenario on synced ledger', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    devices.send(
      PercAmount.fromPerc(0.00000005),
      deliverInstantly: true,
    );

    expect(devices.sender.pendingInboundFor('bob'), hasLength(1));

    devices.relayInitiationToReceiver();
    devices.loginReceiver();

    expect(devices.receiver.pendingInboundFor('bob'), hasLength(1));
    expect(devices.receiver.account('bob')!.balance, PercAmount.zero);

    devices.crossDeviceScenarioAndSettle();
    expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
    expect(
      devices.receiver.account('bob')!.balance,
      PercAmount.fromPerc(0.00000005),
    );
    expect(devices.receiver.account('bob')!.transactions, isNotEmpty);
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