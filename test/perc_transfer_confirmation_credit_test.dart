import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

import 'support/two_device_harness.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

PercTransaction? _inboundTransferTx(PercLedger ledger, String username) {
  final txs = ledger.account(username)?.transactions ?? const [];
  for (final tx in txs) {
    if (tx.kind == PercTxKind.transfer && tx.toUsername == username) {
      return tx;
    }
  }
  return null;
}

void main() {
  test('confirmationsRequired remains 1', () {
    expect(PercChainConstants.confirmationsRequired, 1);
  });

  test('same-device send credits receiver only with confirmed inbound tx', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000007);
    final bobBefore = ledger.account('bob')!.balance;

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: amount,
      deliverInstantly: false,
    );

    final inbound = _inboundTransferTx(ledger, 'bob');
    expect(inbound, isNotNull);
    expect(inbound!.isConfirmed, isTrue);
    expect(inbound.confirmations, greaterThanOrEqualTo(1));
    expect(ledger.account('bob')!.balance - bobBefore, amount);
  });

  test('cross-device pending lists unconfirmed inbound without balance credit', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000006);
    devices.send(amount, deliverInstantly: false);

    final relay = PercLedger.fromJson(devices.sender.toJson());
    devices.receiver.mergePendingInboundFromPeer(relay);

    final bobBefore = devices.receiver.account('bob')!.balance;
    final inbound = _inboundTransferTx(devices.receiver, 'bob');
    expect(inbound, isNotNull);
    expect(inbound!.isConfirmed, isFalse);
    expect(inbound.confirmations, 0);
    expect(devices.receiver.account('bob')!.balance, bobBefore);
  });

  test('cross-device relay credits receiver once tx reaches 1 confirmation', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.send(amount, deliverInstantly: false);
    devices.pushSendToReceiver();
    devices.loginReceiver();

    final inbound = _inboundTransferTx(devices.receiver, 'bob');
    expect(inbound, isNotNull);
    expect(inbound!.isConfirmed, isTrue);
    expect(inbound.confirmations, greaterThanOrEqualTo(1));
    expect(devices.receiver.account('bob')!.balance, amount);
  });

  test('manual settlePendingInboundOnActivity credits on confirmation boundary', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000008);
    devices.send(amount, deliverInstantly: false);

    final relay = PercLedger.fromJson(devices.sender.toJson());
    devices.receiver.mergePendingInboundFromPeer(relay);
    devices.loginReceiver();

    final pending =
        devices.receiver.pendingInboundFor(devices.receiverUser).single;
    final bobBefore = devices.receiver.account('bob')!.balance;
    final beforeTx = _inboundTransferTx(devices.receiver, 'bob');
    expect(beforeTx, isNotNull);
    expect(beforeTx!.isConfirmed, isFalse);
    expect(devices.receiver.account('bob')!.balance, bobBefore);

    devices.receiver.settlePendingInboundOnActivity(
      devices.receiverUser,
      senderPeer: devices.sender,
      now: pending.sentAt,
    );

    final afterTx = _inboundTransferTx(devices.receiver, 'bob');
    expect(afterTx, isNotNull);
    expect(afterTx!.isConfirmed, isTrue);
    expect(afterTx.confirmations, greaterThanOrEqualTo(1));
    expect(devices.receiver.account('bob')!.balance - bobBefore, amount);
    expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
  });
}