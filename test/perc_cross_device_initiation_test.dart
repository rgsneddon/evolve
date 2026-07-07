import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

import 'support/two_device_harness.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('receiver sees pending inbound tx immediately on relay ingestion', () {
    final sender = PercLedger.empty();
    _seed(sender);
    sender.register('alice', 'password123');
    sender.register('bob', 'password123');
    sender.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000010);
    sender.send(
      fromUsername: 'alice',
      toAddress: _addr(sender, 'bob'),
      amount: amount,
      deliverInstantly: false,
    );

    expect(sender.account('bob')!.transactions, isNotEmpty);
    expect(
      sender.account('alice')!.transactions.any(
            (tx) => tx.kind == PercTxKind.transfer && !tx.isConfirmed,
          ),
      isTrue,
    );

    final receiver = PercLedger.empty();
    _seed(receiver);
    receiver.register('bob', 'password123');
    receiver.login('bob', 'password123');

    expect(receiver.account('bob')!.transactions, isEmpty);
    expect(receiver.pendingInboundFor('bob'), isEmpty);

    receiver.ingestInboundTransferInitiation(sender);

    expect(receiver.pendingInboundFor('bob'), hasLength(1));
    expect(receiver.account('bob')!.balance, PercAmount.zero);
    expect(
      receiver.account('bob')!.transactions.any(
            (tx) =>
                tx.kind == PercTxKind.transfer &&
                tx.amount == amount &&
                !tx.isConfirmed,
          ),
      isTrue,
    );
  });

  test('initiation ingestion does not credit spendable balance before scenario', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.send(amount, deliverInstantly: false);

    devices.relayInitiationToReceiver();
    devices.loginReceiver();

    expect(devices.receiver.account('bob')!.balance, PercAmount.zero);
    devices.receiverScenario();
    expect(devices.receiver.account('bob')!.balance, amount);
    expect(
      devices.receiver.account('bob')!.transactions.any((tx) => tx.isConfirmed),
      isTrue,
    );
  });
}