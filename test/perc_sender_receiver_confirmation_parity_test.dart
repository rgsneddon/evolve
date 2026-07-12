import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

import 'support/two_device_harness.dart';

PercTransaction? _inboundTransferTx(PercLedger ledger, String username) {
  final txs = ledger.account(username)?.transactions ?? const [];
  for (final tx in txs) {
    if (tx.kind == PercTxKind.transfer && tx.toUsername == username) {
      return tx;
    }
  }
  return null;
}

PercTransaction? _outboundTransferTx(PercLedger ledger, String username) {
  final txs = ledger.account(username)?.transactions ?? const [];
  for (final tx in txs) {
    if (tx.kind == PercTxKind.transfer && tx.fromUsername == username) {
      return tx;
    }
  }
  return null;
}

void main() {
  test(
    'instantLocal sender relay credits separate receiver with confirmed inbound',
    () {
      final sender = PercLedger.empty();
      TwoDeviceHarness.seed(sender);
      sender.register('alice', 'password123');
      sender.register('bob', 'password123');
      sender.creditScenario(username: 'alice', percentChance: 50);
      sender.login('alice', 'password123');

      final receiver = PercLedger.empty();
      TwoDeviceHarness.seed(receiver);
      TwoDeviceHarness.adoptRegisteredAccount(
        target: receiver,
        source: sender,
        username: 'bob',
      );

      final amount = PercAmount.fromPerc(0.00000007);
      sender.send(
        fromUsername: 'alice',
        toAddress: sender.account('bob')!.address,
        amount: amount,
        deliverInstantly: false,
      );

      expect(sender.pendingInboundFor('bob'), isEmpty);
      expect(_outboundTransferTx(sender, 'alice')!.isConfirmed, isTrue);
      expect(_inboundTransferTx(sender, 'bob')!.isConfirmed, isTrue);

      receiver.applyInboundRelayFromSender(sender);
      receiver.login('bob', 'password123');

      final inbound = _inboundTransferTx(receiver, 'bob');
      expect(inbound, isNotNull);
      expect(inbound!.isConfirmed, isTrue);
      expect(receiver.pendingInboundFor('bob'), isEmpty);
      expect(receiver.account('bob')!.balance, amount);
    },
  );

  test(
    'receiver pending clears when sender peer outbound already confirmed',
    () {
      final devices = TwoDeviceHarness.create();
      devices.linkDevices();
      devices.fundSender();
      devices.loginSender();

      final amount = PercAmount.fromPerc(0.00000005);
      devices.send(amount, deliverInstantly: false);

      final preRelay = PercLedger.fromJson(devices.sender.toJson());
      devices.pushSendToReceiver();
      devices.propagateWitnessToSender();

      expect(_outboundTransferTx(devices.sender, 'alice')!.isConfirmed, isTrue);

      final stuck = PercLedger.empty();
      TwoDeviceHarness.seed(stuck);
      TwoDeviceHarness.adoptRegisteredAccount(
        target: stuck,
        source: devices.receiver,
        username: 'bob',
      );
      stuck.mergePendingInboundFromPeer(preRelay);
      stuck.login('bob', 'password123');

      expect(_inboundTransferTx(stuck, 'bob')!.isConfirmed, isFalse);
      expect(stuck.pendingInboundFor('bob'), hasLength(1));
      expect(stuck.account('bob')!.balance, PercAmount.zero);

      stuck.applyInboundRelayFromSender(devices.sender);

      final inbound = _inboundTransferTx(stuck, 'bob');
      expect(inbound, isNotNull);
      expect(inbound!.isConfirmed, isTrue);
      expect(stuck.pendingInboundFor('bob'), isEmpty);
      expect(stuck.account('bob')!.balance, amount);
    },
  );

  test(
    'sender-confirmed and receiver-confirmed share transfer id after relay',
    () {
      final devices = TwoDeviceHarness.create();
      devices.linkDevices();
      devices.fundSender();
      devices.loginSender();

      final amount = PercAmount.fromPerc(0.00000006);
      devices.sendAndRelay(amount, deliverInstantly: false);
      devices.propagateWitnessToSender();
      devices.loginReceiver();

      final outbound = _outboundTransferTx(devices.sender, 'alice');
      final inbound = _inboundTransferTx(devices.receiver, 'bob');
      expect(outbound, isNotNull);
      expect(inbound, isNotNull);
      expect(outbound!.id, inbound!.id);
      expect(outbound.isConfirmed, isTrue);
      expect(inbound.isConfirmed, isTrue);
      expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
      expect(devices.receiver.account('bob')!.balance, amount);
    },
  );
}