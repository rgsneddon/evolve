import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_faucet.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_staking.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
  ledger.register('staker', 'password123');
}

void main() {
  test('staking reward is flat 0.00000005 PERC per block', () {
    expect(PercStaking.rewardPerBlock.microUnits, 5);
    expect(PercStaking.rewardPerBlock.displayFixed8, '0.00000005');
  });

  test('confirmed balance excludes same-block incoming credits', () {
    expect(
      PercStaking.confirmedBalanceForStaking(
        walletBalance: PercAmount.fromPerc(1),
        sameBlockIncoming: PercAmount.fromPerc(1),
      ),
      PercAmount.zero,
    );
    expect(
      PercStaking.confirmedBalanceForStaking(
        walletBalance: PercAmount.fromPerc(2),
        sameBlockIncoming: PercAmount.fromPerc(0.5),
      ),
      PercAmount.fromPerc(1.5),
    );
  });

  test('flat 0.00000005 PERC for any positive held balance', () {
    expect(
      PercStaking.rewardForBalance(PercAmount.scenarioBaseReward).microUnits,
      5,
    );
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(1)).microUnits,
      5,
    );
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(100)).microUnits,
      5,
    );
    expect(
      PercStaking.rewardForBalance(PercAmount.zero).microUnits,
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
      staker.transactions.where((t) => t.kind == PercTxKind.stakingReward).length,
      1,
    );
  });

  test('staking pays flat amount to all holders on block', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'staker', percentChance: 50);
    ledger.account('staker')!.balance = PercAmount.fromPerc(2);
    ledger.account('bob')!.balance = PercAmount.fromPerc(1);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final treasuryBefore = treasury.balance;

    ledger.creditScenario(username: 'bob', percentChance: 20);

    final staker = ledger.account('staker')!;
    final bob = ledger.account('bob')!;

    expect(staker.cumulativeStakingEarned.microUnits, 5);
    expect(bob.cumulativeStakingEarned.microUnits, 5);
    expect(
      treasury.balance.microUnits,
      treasuryBefore.microUnits -
          PercStaking.rewardPerBlock.microUnits * 2 -
          PercFaucet.computeScenarioReward(percentChance: 20).total.microUnits,
    );
  });

  test('staking rewards confirm in one block', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'staker', percentChance: 10);
    ledger.creditScenario(username: 'bob', percentChance: 10);

    final reward = ledger
        .account('staker')!
        .transactions
        .firstWhere((t) => t.kind == PercTxKind.stakingReward);
    expect(
      reward.confirmations,
      PercChainConstants.stakingConfirmationsRequired,
    );
    expect(reward.isConfirmed, isTrue);
  });
}