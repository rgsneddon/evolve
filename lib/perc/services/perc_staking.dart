import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Cumulative staking — 0.00000005 PERC per 1 PERC held per scenario block.
class PercStaking {
  const PercStaking._();

  /// 0.00000005 PERC earned per 1 PERC held (5 micro-units per 100M micro-units).
  static const PercAmount rewardPerPercHeld = PercAmount(5);

  /// Reward for exactly 1 PERC held — alias kept for treasury-reserve tests.
  static PercAmount get rewardPerBlock => rewardPerPercHeld;

  /// Balance eligible for staking after [PercChainConstants.stakingConfirmationsRequired].
  static PercAmount confirmedBalanceForStaking({
    required PercAmount walletBalance,
    required PercAmount sameBlockIncoming,
  }) {
    final confirmed = walletBalance - sameBlockIncoming;
    if (!confirmed.isPositive) return PercAmount.zero;
    return confirmed;
  }

  /// Proportional staking payout: [rewardPerPercHeld] per whole-PERC fraction held.
  static PercAmount rewardForBalance(PercAmount balance) {
    if (!balance.isPositive) return PercAmount.zero;
    final micro = (balance.microUnits * rewardPerPercHeld.microUnits) ~/
        PercChainConstants.centsPerPerc;
    if (micro <= 0) return PercAmount.zero;
    return PercAmount(micro);
  }
}