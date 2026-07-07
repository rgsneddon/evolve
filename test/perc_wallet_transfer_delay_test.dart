import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_staking.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  tearDown(() {
    PercChainConstants.walletInboundRevertWindowOverride = null;
  });

  test('recipient receives PERC near-instantly on same-device send', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000010),
    );
    expect(
      ledger.account('bob')!.balance,
      PercAmount.fromPerc(0.00000010),
    );
    expect(ledger.pendingInboundFor('bob'), isEmpty);
  });

  test('expired unsettled inbound reverts PERC to sender', () {
    PercChainConstants.walletInboundRevertWindowOverride =
        const Duration(seconds: 2);

    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final transfer = PercAmount.fromPerc(0.00000010);
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: transfer,
    );
    expect(ledger.account('bob')!.balance, transfer);

    ledger.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'tx-stale-pending',
        fromUsername: 'alice',
        toUsername: 'bob',
        amount: PercAmount.fromPerc(0.00000005),
        fee: PercChainConstants.sendTransactionFee,
        sentAt: DateTime.utc(2026, 1, 1),
      ),
    );
    ledger.account('bob')!.balance = PercAmount.zero;
    final aliceBefore = ledger.account('alice')!.balance;

    ledger.refreshPendingInboundTransfers(
      now: DateTime.utc(2026, 1, 1, 0, 0, 3),
    );

    expect(ledger.pendingInboundFor('bob'), isEmpty);
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.account('alice')!.balance, aliceBefore);
    expect(
      ledger.account('alice')!.transactions.any(
            (t) => t.kind == PercTxKind.transferRevert,
          ),
      isTrue,
    );
  });

  test('production inbound revert window is 24 hours for undelivered relay', () {
    expect(
      PercChainConstants.walletInboundRevertWindow,
      const Duration(hours: 24),
    );
    expect(
      PercChainConstants.walletInboundRevertWindow.inDays,
      lessThan(365),
    );
  });
}