import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_staking.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.login(PercChainConstants.treasuryUsername, 'password123');
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  tearDown(() {
    PercChainConstants.walletOnlineReceiveDelayOverride = null;
  });

  test('offline recipient receives PERC after online receive delay', () {
    PercChainConstants.walletOnlineReceiveDelayOverride =
        const Duration(seconds: 2);

    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    ledger.send(
      fromUsername: 'alice',
      toUsername: 'bob',
      amount: PercAmount.fromPerc(0.00000010),
    );
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.pendingInboundFor('bob'), hasLength(1));

    final onlineAt = DateTime.utc(2026, 1, 1, 12);
    ledger.login('bob', 'password123', now: onlineAt);
    expect(ledger.account('bob')!.balance, PercAmount.zero);

    ledger.login(
      'bob',
      'password123',
      now: onlineAt.add(const Duration(seconds: 1)),
    );
    expect(ledger.account('bob')!.balance, PercAmount.zero);

    ledger.login(
      'bob',
      'password123',
      now: onlineAt.add(const Duration(seconds: 2)),
    );
    final transfer = PercAmount.fromPerc(0.00000010);
    expect(
      ledger.account('bob')!.balance,
      transfer + PercStaking.rewardPerBlock,
    );
    expect(ledger.pendingInboundFor('bob'), isEmpty);
  });

  test('production wallet online receive delay is 12 months', () {
    expect(
      PercChainConstants.walletOnlineReceiveDelay,
      const Duration(days: 365),
    );
  });
}