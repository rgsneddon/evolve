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

/// Plan acceptance bound for burst relay pickup.
const Duration burstPickupDeadline = Duration(seconds: 5);

bool _receiverSettled(
  PercLedgerHub hub,
  String receiverUser,
  PercAmount expectedAmount,
) {
  return hub.ledger.pendingInboundFor(receiverUser).isEmpty &&
      hub.ledger.sessionBalance == expectedAmount;
}

/// Drives in-flight burst cycles until the receiver credits or the deadline hits.
Future<Duration> awaitBurstSettlement({
  required PercNetworkCoordinator coordinator,
  required PercLedgerHub hub,
  required String receiverUser,
  required PercAmount expectedAmount,
  Duration deadline = burstPickupDeadline,
}) async {
  final started = DateTime.now();
  final limit = started.add(deadline);

  while (DateTime.now().isBefore(limit)) {
    if (_receiverSettled(hub, receiverUser, expectedAmount)) {
      final elapsed = DateTime.now().difference(started);
      // ignore: avoid_print
      print('burst_pickup_elapsed_ms=${elapsed.inMilliseconds}');
      return elapsed;
    }
    if (coordinator.burstActiveForTest ||
        coordinator.burstAttemptsRemainingForTest > 0) {
      await coordinator.runBurstInboundCycleForTest();
      continue;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  final elapsed = DateTime.now().difference(started);
  // ignore: avoid_print
  print('burst_pickup_elapsed_ms=${elapsed.inMilliseconds} (deadline)');
  return elapsed;
}

Future<({
  PercLedgerHub hub,
  PercNetworkCoordinator coordinator,
  TwoDeviceHarness devices,
  PercAmount amount,
})> _receiverHarnessWithRelayPending({
  PercAmount? amount,
}) async {
  final devices = TwoDeviceHarness.create();
  devices.linkDevices();
  devices.fundSender();
  devices.loginSender();

  final sendAmount = amount ?? PercAmount.fromPerc(0.00000010);
  devices.send(sendAmount, deliverInstantly: false);

  final hub = PercLedgerHub.instance;
  TwoDeviceHarness.seed(hub.ledger);
  TwoDeviceHarness.adoptRegisteredAccount(
    target: hub.ledger,
    source: devices.receiver,
    username: devices.receiverUser,
  );
  hub.ledger.login(devices.receiverUser, devices.password);
  hub.ledger.mergeDiscoverableAccounts(devices.sender);

  final coordinator = PercNetworkCoordinator.instance;
  await coordinator.bind(hub);
  await coordinator.onSessionStarted(devices.receiverUser);

  return (
    hub: hub,
    coordinator: coordinator,
    devices: devices,
    amount: sendAmount,
  );
}

void main() {
  setUp(() {
    PercNetworkCoordinator.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test(
    'burst ingests sender relay and credits receiver within 5s window',
    () async {
      final ctx = await _receiverHarnessWithRelayPending();
      final coordinator = ctx.coordinator;
      final hub = ctx.hub;
      final devices = ctx.devices;
      final amount = ctx.amount;

      coordinator.scheduleInboundBurst(
        senderUsernames: [devices.senderUser],
      );
      await coordinator.runBurstInboundCycleForTest();
      expect(hub.ledger.sessionBalance, PercAmount.zero);

      final pickupStarted = DateTime.now();
      await coordinator.pushLedgerToRecipient(
        ledger: devices.sender,
        username: devices.receiverUser,
      );

      final elapsed = await awaitBurstSettlement(
        coordinator: coordinator,
        hub: hub,
        receiverUser: devices.receiverUser,
        expectedAmount: amount,
      );

      expect(
        elapsed,
        lessThan(burstPickupDeadline),
        reason: 'burst must credit within $burstPickupDeadline',
      );
      expect(hub.ledger.pendingInboundFor(devices.receiverUser), isEmpty);
      expect(hub.ledger.sessionBalance, amount);
      expect(
        DateTime.now().difference(pickupStarted),
        lessThan(burstPickupDeadline),
      );
    },
  );

  test(
    'pushLedgerToRecipient credits logged-in receiver immediately',
    () async {
      final ctx = await _receiverHarnessWithRelayPending(
        amount: PercAmount.fromPerc(0.00000008),
      );
      final coordinator = ctx.coordinator;
      final hub = ctx.hub;
      final devices = ctx.devices;
      final amount = ctx.amount;

      final pickupStarted = DateTime.now();
      await coordinator.pushLedgerToRecipient(
        ledger: devices.sender,
        username: devices.receiverUser,
      );

      final hints = await const PercNetworkRendezvous()
          .fetchInboundRelayHints(recipientUsername: devices.receiverUser);
      expect(hints, isNotEmpty);
      expect(hints.first.senderUsername, devices.senderUser);

      expect(hub.ledger.pendingInboundFor(devices.receiverUser), isEmpty);
      expect(hub.ledger.sessionBalance, amount);
      expect(
        DateTime.now().difference(pickupStarted),
        lessThan(AppPerformance.foregroundNetworkPoll),
        reason: 'wake-on-push must credit before foreground poll interval',
      );

      await coordinator.pollForInboundTransfers();
      expect(hub.ledger.sessionBalance, amount);
    },
  );

  test('refreshInboundNow credits receiver after relay while logged out', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password123');
    await wallet.register('bob', 'password123');
    final bobAddr = wallet.addressForUsername('bob');
    await wallet.logout();

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

    final pickupStarted = DateTime.now();
    await wallet.refreshInboundNow();
    final elapsed = DateTime.now().difference(pickupStarted);
    // ignore: avoid_print
    print('refresh_burst_pickup_elapsed_ms=${elapsed.inMilliseconds}');

    expect(elapsed, lessThan(burstPickupDeadline));
    expect(wallet.pendingInboundTransfers, isEmpty);
    expect(wallet.balance, amount);
  });
}