import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_staking.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.register('staker', 'password123');
}

void main() {
  test('staking unit is 10% of 0.00000050 PERC per PERC held', () {
    expect(PercStaking.unitRewardPerPerc.microUnits, 5);
    expect(PercStaking.unitRewardPerPerc.displayFixed8, '0.00000005');
  });

  test('staking reward scales with held balance', () {
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(1)).microUnits,
      5,
    );
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(2)).microUnits,
      10,
    );
    expect(
      PercStaking.rewardForBalance(PercAmount.scenarioBaseReward).microUnits,
      0,
    );
  });

  test('cumulative staking credited on scenario block', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'staker', percentChance: 10);
    ledger.account('staker')!.balance = PercAmount.fromPerc(1);

    ledger.creditScenario(username: 'bob', percentChance: 10);
    final staker = ledger.account('staker')!;
    expect(staker.cumulativeStakingEarned.microUnits, 5);
    expect(
      staker.transactions.any((t) => t.kind == PercTxKind.stakingReward),
      isTrue,
    );
  });

  test('staking pays from treasury to all holders on block', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'staker', percentChance: 50);
    ledger.account('staker')!.balance = PercAmount.fromPerc(2);
    ledger.account('bob')!.balance = PercAmount.fromPerc(1);

    final bobBalanceBefore = ledger.account('bob')!.balance;
    ledger.creditScenario(username: 'bob', percentChance: 20);

    final staker = ledger.account('staker')!;
    final bob = ledger.account('bob')!;

    expect(staker.cumulativeStakingEarned.microUnits, 10);
    expect(bob.balance.microUnits, greaterThan(bobBalanceBefore.microUnits));
  });
}