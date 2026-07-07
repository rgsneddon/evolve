import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/treasury_scenario_settlement.dart';

void main() {
  final reserve = PercChainConstants.minimumTreasuryReserve;
  final reward = PercAmount.fromPerc(0.00000050);
  final bootstrap = PercChainConstants.treasuryLaunchAllocation;

  test('reward debits from pre-draw balance when treasury covers payout', () {
    final ops = TreasuryScenarioSettlement.plan(
      preDrawBalance: PercAmount.fromPerc(1),
      minimumReserve: reserve,
      reward: reward,
      treasuryGenesisDone: true,
      bootstrapAmount: PercAmount.zero,
      accrualAmount: PercAmount.fromPerc(0.00000010),
      skipPayout: false,
    );

    expect(
      TreasuryScenarioSettlement.indexOfDebitReward(ops),
      lessThan(TreasuryScenarioSettlement.indexOfFirstMint(ops)),
    );
    expect(ops.first.kind, TreasuryScenarioOpKind.debitReward);
    expect(ops.last.kind, TreasuryScenarioOpKind.mintAccrual);
  });

  test('reserve blocks payout with no debit op', () {
    final ops = TreasuryScenarioSettlement.plan(
      preDrawBalance: reward,
      minimumReserve: reserve,
      reward: reward,
      treasuryGenesisDone: true,
      bootstrapAmount: PercAmount.zero,
      accrualAmount: PercAmount.zero,
      skipPayout: false,
    );

    expect(
      ops.any((o) => o.kind == TreasuryScenarioOpKind.debitReward),
      isFalse,
    );
  });

  test('bootstrap and accrual never precede debit in plan order', () {
    final ops = TreasuryScenarioSettlement.plan(
      preDrawBalance: PercAmount.fromPerc(1),
      minimumReserve: reserve,
      reward: reward,
      treasuryGenesisDone: false,
      bootstrapAmount: bootstrap,
      accrualAmount: PercAmount.fromPerc(0.00000005),
      skipPayout: false,
    );

    final debitIdx = TreasuryScenarioSettlement.indexOfDebitReward(ops);
    final mintIdx = TreasuryScenarioSettlement.indexOfFirstMint(ops);
    expect(debitIdx, greaterThanOrEqualTo(0));
    expect(mintIdx, greaterThan(debitIdx));
    expect(
      ops.where((o) => o.kind == TreasuryScenarioOpKind.mintBootstrap).length,
      1,
    );
  });

  test('cooldown skips payout but still allows accrual mint after', () {
    final ops = TreasuryScenarioSettlement.plan(
      preDrawBalance: PercAmount.fromPerc(5),
      minimumReserve: reserve,
      reward: reward,
      treasuryGenesisDone: true,
      bootstrapAmount: PercAmount.zero,
      accrualAmount: PercAmount.fromPerc(0.00000001),
      skipPayout: true,
    );

    expect(
      ops.any((o) => o.kind == TreasuryScenarioOpKind.debitReward),
      isFalse,
    );
    expect(ops.first.kind, TreasuryScenarioOpKind.mintAccrual);
  });
}