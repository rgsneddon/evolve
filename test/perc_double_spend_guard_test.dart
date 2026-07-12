import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_transfer_relay_ack.dart';

import 'support/two_device_harness.dart';

void main() {
  test('relay settlement does not double-credit same transfer id', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password123');
    ledger.launchBlockchain();
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000010);
    const fee = PercChainConstants.sendTransactionFee;
    ledger.account('alice')!.balance = amount + fee;

    final tx = ledger.send(
      fromUsername: 'alice',
      toAddress: ledger.account('bob')!.address,
      amount: amount,
      deliverInstantly: false,
    );

    final bobBefore = ledger.account('bob')!.balance.microUnits;
    expect(bobBefore, amount.microUnits);

    final pending = PercPendingInboundTransfer(
      id: tx.id,
      fromUsername: 'alice',
      toUsername: 'bob',
      amount: amount,
      fee: fee,
      sentAt: DateTime.now().toUtc(),
    );
    ledger.settlePendingInboundOnActivity('bob', now: pending.sentAt);
    final afterFirst = ledger.account('bob')!.balance.microUnits;
    expect(afterFirst, bobBefore);

    ledger.pendingInboundTransfers.add(pending);
    ledger.settlePendingInboundOnActivity('bob', now: pending.sentAt);
    expect(ledger.account('bob')!.balance.microUnits, afterFirst);
    expect(
      ledger.account('bob')!.transactions
          .where((t) => t.id == tx.id && t.isConfirmed)
          .length,
      lessThanOrEqualTo(1),
    );
  });

  test('applyInboundRelayFromSender twice does not double-credit receiver', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000008);
    devices.send(amount, deliverInstantly: false);
    devices.loginReceiver();

    devices.receiver.applyInboundRelayFromSender(devices.sender);
    final afterFirst = devices.receiver.account('bob')!.balance.microUnits;
    expect(afterFirst, amount.microUnits);

    devices.receiver.applyInboundRelayFromSender(devices.sender);
    expect(devices.receiver.account('bob')!.balance.microUnits, afterFirst);
    expect(
      devices.receiver.account('bob')!.transactions
          .where((t) => t.kind == PercTxKind.transfer && t.isConfirmed)
          .length,
      lessThanOrEqualTo(1),
    );
  });

  test('outbound hold prevents second send spending reserved PERC', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000010);
    devices.send(amount, deliverInstantly: false);

    final spendable = devices.sender.sessionBalance;
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

  test('PercTransferRelayAck skips block containing any known transfer id', () {
    final canonical = PercLedger.empty();
    canonical.networkGenesisRevision = 2;
    canonical.blocks.add(
      PercBlock(
        index: 0,
        timestamp: DateTime.utc(2026, 1, 1),
        treasuryEmitted: PercAmount.zero,
        transactions: [
          PercTransaction(
            id: 'tx-known',
            kind: PercTxKind.transfer,
            amount: PercAmount.fromPerc(0.00000001),
            timestamp: DateTime.utc(2026, 1, 1),
            blockIndex: 0,
          ),
        ],
      ),
    );

    final relay = PercLedger.empty();
    relay.networkGenesisRevision = 2;
    relay.blocks.add(
      PercBlock(
        index: 1,
        timestamp: DateTime.utc(2026, 1, 2),
        treasuryEmitted: PercAmount.zero,
        transactions: [
          PercTransaction(
            id: 'tx-known',
            kind: PercTxKind.transfer,
            amount: PercAmount.fromPerc(0.00000001),
            timestamp: DateTime.utc(2026, 1, 2),
            blockIndex: 1,
          ),
          PercTransaction(
            id: 'tx-new',
            kind: PercTxKind.transfer,
            amount: PercAmount.fromPerc(0.00000002),
            timestamp: DateTime.utc(2026, 1, 2),
            blockIndex: 1,
          ),
        ],
      ),
    );

    final result = PercTransferRelayAck.acknowledgeRelayTransfers(
      canonical,
      relay,
    );
    expect(result.ok, isFalse);
    expect(canonical.blocks.length, 1);
    expect(
      canonical.blocks.expand((b) => b.transactions).map((t) => t.id).toSet(),
      {'tx-known'},
    );
  });

  test(
    're-injected settled pending does not double-debit sender with surplus balance',
    () {
      final ledger = PercLedger.empty();
      ledger.ensureTreasuryAccount();
      ledger.setupTreasuryPassword('password123');
      ledger.launchBlockchain();
      ledger.register('alice', 'password123');
      ledger.register('bob', 'password123');
      ledger.creditScenario(username: 'alice', percentChance: 50);
      final aliceStart = ledger.account('alice')!.balance;

      final amount = PercAmount.fromPerc(0.00000008);
      const fee = PercChainConstants.sendTransactionFee;
      final sentAt = DateTime.now().toUtc();
      const txId = 'tx-replay-surplus';
      final pending = PercPendingInboundTransfer(
        id: txId,
        fromUsername: 'alice',
        toUsername: 'bob',
        amount: amount,
        fee: fee,
        sentAt: sentAt,
      );
      ledger.pendingInboundTransfers.add(pending);

      ledger.settlePendingInboundOnActivity('bob', now: sentAt);
      final aliceAfterSettle = ledger.account('alice')!.balance;
      expect(aliceAfterSettle.microUnits, lessThan(aliceStart.microUnits));

      ledger.pendingInboundTransfers.add(pending);
      ledger.settlePendingInboundOnActivity('bob', now: sentAt);

      expect(ledger.account('alice')!.balance, aliceAfterSettle);
      expect(
        ledger.account('bob')!.transactions
            .where((t) => t.id == txId && t.isConfirmed)
            .length,
        1,
      );
    },
  );

  test('mergePendingInboundFromPeer ignores settled transfer ids', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password123');
    ledger.launchBlockchain();
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000006);
    const fee = PercChainConstants.sendTransactionFee;
    final sentAt = DateTime.now().toUtc();
    const txId = 'tx-merge-settled';
    final pending = PercPendingInboundTransfer(
      id: txId,
      fromUsername: 'alice',
      toUsername: 'bob',
      amount: amount,
      fee: fee,
      sentAt: sentAt,
    );
    ledger.pendingInboundTransfers.add(pending);
    ledger.settlePendingInboundOnActivity('bob', now: sentAt);
    expect(ledger.pendingInboundFor('bob'), isEmpty);

    final remote = PercLedger.fromJson(ledger.toJson());
    remote.pendingInboundTransfers.add(pending);
    ledger.mergePendingInboundFromPeer(remote);
    expect(ledger.pendingInboundFor('bob'), isEmpty);
  });

  test('witness propagate does not double-debit sender', () {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.sendAndRelay(amount, deliverInstantly: false);
    devices.loginReceiver();

    final aliceBefore = devices.sender.account('alice')!.balance;
    devices.propagateWitnessToSender();
    final afterFirst = devices.sender.account('alice')!.balance;

    devices.propagateWitnessToSender();
    expect(devices.sender.account('alice')!.balance, afterFirst);
    expect(afterFirst.microUnits, lessThan(aliceBefore.microUnits));
  });
}