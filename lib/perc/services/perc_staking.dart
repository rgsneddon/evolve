import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Cumulative staking — 10% of the 0.00000050 PERC base per PERC held per block.
class PercStaking {
  const PercStaking._();

  /// 10% of scenario base reward (0.00000005 PERC = 5 micro-units per 1 PERC held).
  static PercAmount get unitRewardPerPerc {
    final base = PercChainConstants.scenarioBaseReward.microUnits;
    final micro = (base * PercChainConstants.stakingYieldPercent) ~/ 100;
    return PercAmount(micro);
  }

  static PercAmount rewardForBalance(PercAmount balance) {
    if (!balance.isPositive) return PercAmount.zero;
    final micro = (balance.microUnits * unitRewardPerPerc.microUnits) ~/
        PercAmount.unitsPerPerc;
    return PercAmount(micro);
  }
}