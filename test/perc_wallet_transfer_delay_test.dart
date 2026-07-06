import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
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
    PercChainConstants.walletOnlineReceiveDelayOverride = null;
  });

  test('offline recipient receives PERC after scenario activity within receive window', () {
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
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.pendingInboundFor('bob'), hasLength(1));

    ledger.login('bob', 'password123');
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.pendingInboundFor('bob'), hasLength(1));

    ledger.advanceScenarioBlock('bob');
    expect(
      ledger.account('bob')!.balance,
      PercAmount.fromPerc(0.00000010),
    );
    expect(ledger.pendingInboundFor('bob'), isEmpty);
  });

  test('expired pending inbound reverts PERC to sender', () {
    PercChainConstants.walletOnlineReceiveDelayOverride =
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
    final sentAt = ledger.pendingInboundFor('bob').single.sentAt;
    final aliceAfterSend = ledger.account('alice')!.balance;

    ledger.refreshPendingInboundTransfers(
      now: sentAt.add(const Duration(seconds: 3)),
    );

    expect(ledger.pendingInboundFor('bob'), isEmpty);
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(
      ledger.account('alice')!.balance,
      aliceAfterSend + transfer + PercStaking.rewardPerBlock,
    );
    expect(
      ledger.account('alice')!.transactions.any(
            (t) => t.kind == PercTxKind.transferRevert,
          ),
      isTrue,
    );
  });

  test('production wallet online receive delay is 12 months', () {
    expect(
      PercChainConstants.walletOnlineReceiveDelay,
      const Duration(days: 365),
    );
  });
}