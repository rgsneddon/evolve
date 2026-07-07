import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  test('relay settlement does not double-credit same transfer id', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password123');
    ledger.launchBlockchain();
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    final credit = ledger.creditScenario(username: 'alice', percentChance: 50);
    expect(credit.status.toString(), contains('credited'));

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
  });
}