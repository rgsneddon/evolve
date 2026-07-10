import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_network_rendezvous.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/services/app_performance.dart';

import 'support/two_device_harness.dart';

void main() {
  setUp(() {
    PercNetworkCoordinator.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('burst ingests sender relay and credits receiver in one cycle', () async {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000010);
    devices.send(amount, deliverInstantly: false);

    final hub = PercLedgerHub.instance;
    TwoDeviceHarness.seed(hub.ledger);
    hub.ledger.register(devices.receiverUser, devices.password);
    hub.ledger.login(devices.receiverUser, devices.password);
    hub.ledger.mergeDiscoverableAccounts(devices.sender);

    final coordinator = PercNetworkCoordinator.instance;
    await coordinator.bind(hub);
    await coordinator.onSessionStarted(devices.receiverUser);

    await coordinator.pushLedgerToRecipient(
      ledger: devices.sender,
      username: devices.receiverUser,
    );

    expect(hub.ledger.sessionBalance, PercAmount.zero);
    await coordinator.runBurstInboundCycleForTest();

    expect(hub.ledger.pendingInboundFor(devices.receiverUser), isEmpty);
    expect(hub.ledger.sessionBalance, amount);
    expect(coordinator.burstActiveForTest, isFalse);
  });

  test('relay PUT hint triggers burst pickup without full poll wait', () async {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000008);
    devices.send(amount, deliverInstantly: false);

    final hub = PercLedgerHub.instance;
    TwoDeviceHarness.seed(hub.ledger);
    hub.ledger.register(devices.receiverUser, devices.password);
    hub.ledger.login(devices.receiverUser, devices.password);
    hub.ledger.mergeDiscoverableAccounts(devices.sender);

    final coordinator = PercNetworkCoordinator.instance;
    await coordinator.bind(hub);
    await coordinator.onSessionStarted(devices.receiverUser);
    await coordinator.pushLedgerToRecipient(
      ledger: devices.sender,
      username: devices.receiverUser,
    );

    final hints = await const PercNetworkRendezvous()
        .fetchInboundRelayHints(recipientUsername: devices.receiverUser);
    expect(hints, isNotEmpty);
    expect(hints.first.senderUsername, devices.senderUser);

    final started = DateTime.now();
    coordinator.scheduleInboundBurst();
    await coordinator.runBurstInboundCycleForTest();
    final elapsed = DateTime.now().difference(started);

    expect(hub.ledger.sessionBalance, amount);
    expect(elapsed, lessThan(AppPerformance.foregroundNetworkPoll));
  });

  test('refreshInboundNow schedules burst sync', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password123');
    await wallet.register('bob', 'password123');
    final bobAddr = wallet.address;

    final sender = PercLedger.empty();
    TwoDeviceHarness.seed(sender);
    sender.register('alice', 'password123');
    sender.login('alice', 'password123');
    sender.mergeDiscoverableAccounts(PercLedgerHub.instance.ledger);
    sender.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000005);
    sender.send(
      fromUsername: 'alice',
      toAddress: bobAddr,
      amount: amount,
      deliverInstantly: false,
    );

    await PercNetworkCoordinator.instance.pushLedgerToRecipient(
      ledger: sender,
      username: 'bob',
    );

    await wallet.login('bob', 'password123');
    expect(wallet.balance, PercAmount.zero);
    await wallet.refreshInboundNow();

    expect(wallet.pendingInboundTransfers, isEmpty);
    expect(wallet.balance, amount);
  });
}