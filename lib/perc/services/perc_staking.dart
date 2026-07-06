import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Cumulative staking — flat 0.00000005 PERC per block for confirmed held PERC.
class PercStaking {
  const PercStaking._();

  /// 10% of 0.00000050 PERC base = 0.00000005 PERC each block.
  static PercAmount get rewardPerBlock {
    final base = PercChainConstants.scenarioBaseReward.microUnits;
    final micro = (base * PercChainConstants.stakingYieldPercent) ~/ 100;
    return PercAmount(micro);
  }

  /// Balance eligible for staking after [PercChainConstants.stakingConfirmationsRequired].
  static PercAmount confirmedBalanceForStaking({
    required PercAmount walletBalance,
    required PercAmount sameBlockIncoming,
  }) {
    final confirmed = walletBalance - sameBlockIncoming;
    if (!confirmed.isPositive) return PercAmount.zero;
    return confirmed;
  }

  /// One flat staking payout per block when confirmed balance is positive.
  static PercAmount rewardForBalance(PercAmount balance) {
    if (!balance.isPositive) return PercAmount.zero;
    return rewardPerBlock;
  }
}