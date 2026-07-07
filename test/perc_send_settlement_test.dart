import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_staking.dart';

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
  test('sender with exact funds debits on near-instant same-device settlement', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    final credit = ledger.creditScenario(username: 'alice', percentChance: 50);
    expect(credit.status, PercFaucetCreditStatus.credited);

    final amount = PercAmount.fromPerc(0.00000010);
    const fee = PercChainConstants.sendTransactionFee;
    final alice = ledger.account('alice')!;
    alice.balance = amount + fee;

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: amount,
      deliverInstantly: false,
    );

    expect(ledger.pendingInboundFor('bob'), isEmpty);
    expect(ledger.account('bob')!.balance.microUnits, amount.microUnits);
    expect(
      alice.transactions
          .firstWhere((tx) => tx.kind == PercTxKind.transfer)
          .isConfirmed,
      isTrue,
    );
    expect(alice.balance.microUnits, lessThan((amount + fee).microUnits));
  });

  test('receiver not credited when local sender lacks funds at settlement', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000010);
    final sentAt = DateTime.now().toUtc();
    ledger.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'tx-defer-local',
        fromUsername: 'alice',
        toUsername: 'bob',
        amount: amount,
        fee: PercChainConstants.sendTransactionFee,
        sentAt: sentAt,
      ),
    );
    ledger.account('alice')!.balance = PercAmount.zero;

    ledger.settlePendingInboundOnActivity('bob', now: sentAt);

    expect(ledger.pendingInboundFor('bob'), hasLength(1));
    expect(ledger.account('bob')!.balance.microUnits, 0);
    expect(
      ledger.account('bob')!.transactions.any((tx) => tx.isConfirmed),
      isFalse,
    );
  });

  test('outbound hold blocks spending reserved PERC before cross-device settlement', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000010);
    devices.send(amount, deliverInstantly: false);

    final spendable = devices.sender.sessionBalance;
    expect(spendable.isPositive, isTrue);
    expect(devices.sender.pendingInboundFor('bob'), hasLength(1));

    expect(
      () => devices.sender.send(
        fromUsername: 'alice',
        toAddress: devices.receiverAddress,
        amount: spendable,
        deliverInstantly: false,
      ),
      throwsStateError,
    );
  });

  test('cross-device defers when sender peer lacks funds at relay settlement', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000010);
    devices.send(amount, deliverInstantly: false);
    devices.sender.account('alice')!.balance = PercAmount.zero;
    devices.pushSendToReceiver();
    devices.loginReceiver();

    expect(devices.receiver.pendingInboundFor('bob'), hasLength(1));
    expect(devices.receiver.account('bob')!.balance.microUnits, 0);
    expect(devices.receiver.settlementWitnesses, isEmpty);
    expect(devices.sender.pendingInboundTransfers, isNotEmpty);
  });

  test('cross-device stays pending until relay arrives', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.send(amount, deliverInstantly: false);
    devices.loginReceiver();

    expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
    expect(devices.receiver.account('bob')!.balance.microUnits, 0);
    expect(devices.receiver.settlementWitnesses, isEmpty);
  });

  test('cross-device relay credits receiver then sender debits on witness propagate', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.sendAndRelay(amount, deliverInstantly: false);
    devices.loginReceiver();

    final aliceBefore = devices.sender.account('alice')!.balance;

    expect(devices.receiver.account('bob')!.balance.microUnits, amount.microUnits);
    expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
    expect(devices.receiver.settlementWitnesses, hasLength(1));
    expect(devices.sender.pendingInboundFor('bob'), hasLength(1));

    devices.propagateWitnessToSender();

    expect(devices.sender.pendingInboundFor('bob'), isEmpty);
    final postDebit = aliceBefore - amount - PercChainConstants.sendTransactionFee;
    final stakingReward = PercStaking.rewardForBalance(postDebit);
    expect(
      devices.sender.account('alice')!.balance,
      postDebit + stakingReward,
    );
    expect(
      devices.sender.account('alice')!.transactions.any(
            (tx) => tx.amount == amount && tx.isConfirmed,
          ),
      isTrue,
    );
  });

  test('cross-device sender debits after witness propagate without scenario', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.send(amount, deliverInstantly: false);

    final aliceBefore = devices.sender.account('alice')!.balance;
    expect(devices.sender.pendingInboundFor('bob'), hasLength(1));

    devices.pushSendToReceiver();
    devices.loginReceiver();
    devices.propagateWitnessToSender();

    expect(devices.receiver.account('bob')!.balance.microUnits, amount.microUnits);
    expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
    expect(devices.receiver.settlementWitnesses, hasLength(1));
    expect(devices.receiver.settlementWitnesses.first.transferId, isNotEmpty);

    expect(devices.sender.pendingInboundFor('bob'), isEmpty);
    final postDebit = aliceBefore - amount - PercChainConstants.sendTransactionFee;
    final stakingReward = PercStaking.rewardForBalance(postDebit);
    expect(
      devices.sender.account('alice')!.balance,
      postDebit + stakingReward,
    );
    expect(
      devices.sender.account('alice')!.transactions.any(
            (tx) => tx.amount == amount && tx.isConfirmed,
          ),
      isTrue,
    );
  });
}