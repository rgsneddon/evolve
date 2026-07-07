import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
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
  test('sender with exact funds debits on recipient scenario (no 2x hold)', () {
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

    ledger.login('alice', 'password123');
    expect(ledger.pendingInboundFor('bob'), hasLength(1));
    expect(ledger.sessionBalance, alice.balance - amount - fee);

    ledger.advanceScenarioBlock('bob');

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

  test('receiver not credited when local sender lacks funds at scenario', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000010);
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: amount,
      deliverInstantly: false,
    );

    ledger.account('alice')!.balance = PercAmount.zero;
    ledger.advanceScenarioBlock('bob');

    expect(ledger.pendingInboundFor('bob'), hasLength(1));
    expect(ledger.account('bob')!.balance.microUnits, 0);
    expect(
      ledger.account('bob')!.transactions.any((tx) => tx.isConfirmed),
      isFalse,
    );
  });

  test('outbound hold blocks spending reserved PERC before settlement', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);
    ledger.login('alice', 'password123');

    final amount = PercAmount.fromPerc(0.00000010);
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: amount,
      deliverInstantly: false,
    );

    final spendable = ledger.sessionBalance;
    expect(spendable.isPositive, isTrue);

    expect(
      () => ledger.send(
        fromUsername: 'alice',
        toAddress: _addr(ledger, 'bob'),
        amount: spendable,
        deliverInstantly: false,
      ),
      throwsStateError,
    );
  });

  test('cross-device defers when sender peer lacks funds at scenario', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000010);
    devices.send(amount, deliverInstantly: false);
    devices.pushSendToReceiver();

    devices.sender.account('alice')!.balance = PercAmount.zero;
    devices.loginReceiver();
    devices.receiverScenario();

    expect(devices.receiver.pendingInboundFor('bob'), hasLength(1));
    expect(devices.receiver.account('bob')!.balance.microUnits, 0);
    expect(devices.receiver.settlementWitnesses, isEmpty);
    expect(devices.sender.pendingInboundTransfers, isNotEmpty);
  });

  test('cross-device defers scenario without live sender peer', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.send(amount, deliverInstantly: false);
    devices.pushSendToReceiver();
    devices.loginReceiver();

    devices.receiver.advanceScenarioBlock('bob');

    expect(devices.receiver.pendingInboundFor('bob'), hasLength(1));
    expect(devices.receiver.account('bob')!.balance.microUnits, 0);
    expect(devices.receiver.settlementWitnesses, isEmpty);
  });

  test('cross-device credits receiver via senderPeerResolver without merge', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.send(amount, deliverInstantly: false);
    devices.pushSendToReceiver();
    devices.loginReceiver();

    devices.receiver.advanceScenarioBlock(
      'bob',
      senderPeerResolver: (from) => from == 'alice' ? devices.sender : null,
    );

    expect(devices.receiver.account('bob')!.balance.microUnits, amount.microUnits);
    expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
    expect(devices.receiver.settlementWitnesses, hasLength(1));
    expect(devices.sender.pendingInboundFor('bob'), hasLength(1));
  });

  test('cross-device sender debits after witness scenario merge', () {
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
    devices.crossDeviceScenarioAndSettle();

    expect(devices.receiver.account('bob')!.balance.microUnits, amount.microUnits);
    expect(devices.receiver.pendingInboundFor('bob'), isEmpty);
    expect(devices.receiver.settlementWitnesses, hasLength(1));
    expect(devices.receiver.settlementWitnesses.first.transferId, isNotEmpty);

    expect(devices.sender.pendingInboundFor('bob'), isEmpty);
    expect(
      devices.sender.account('alice')!.balance.microUnits,
      (aliceBefore - amount - PercChainConstants.sendTransactionFee +
              PercStaking.rewardPerBlock)
          .microUnits,
    );
    expect(
      devices.sender.account('alice')!.transactions.any(
            (tx) => tx.amount == amount && tx.isConfirmed,
          ),
      isTrue,
    );
  });
}