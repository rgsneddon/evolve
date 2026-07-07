import '../models/perc_amount.dart';
import '../models/perc_block.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';

/// Cumulative staking — 0.00000005 PERC per 1 PERC held per valid scenario block.
class PercStaking {
  const PercStaking._();

  /// 0.00000005 PERC earned per 1 PERC held (5 micro-units per 100M micro-units).
  static const PercAmount rewardPerPercHeld = PercAmount(5);

  /// Reward for exactly 1 PERC held — alias kept for treasury-reserve tests.
  static PercAmount get rewardPerBlock => rewardPerPercHeld;

  /// True when [block] finalized a valid scenario (faucet payout), not microblock seals or transfers.
  static bool isScenarioStakingBlock(PercBlock block) {
    if (block.microblockSeal) return false;
    return block.transactions
        .any((tx) => tx.kind == PercTxKind.scenarioReward);
  }

  /// Sum of chain-recorded staking credits owed to [username] across scenario blocks.
  static PercAmount stakingOwedFromChain({
    required Iterable<PercBlock> blocks,
    required String username,
  }) {
    var total = PercAmount.zero;
    for (final block in blocks) {
      if (!isScenarioStakingBlock(block)) continue;
      for (final tx in block.transactions) {
        if (tx.kind == PercTxKind.stakingReward && tx.toUsername == username) {
          total = total + tx.amount;
        }
      }
    }
    return total;
  }

  /// Staking reward transactions recorded on-chain for [username].
  static List<PercTransaction> stakingTransactionsFromChain({
    required Iterable<PercBlock> blocks,
    required String username,
  }) {
    final txs = <PercTransaction>[];
    for (final block in blocks) {
      if (!isScenarioStakingBlock(block)) continue;
      for (final tx in block.transactions) {
        if (tx.kind == PercTxKind.stakingReward && tx.toUsername == username) {
          txs.add(tx);
        }
      }
    }
    return txs;
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

  /// Proportional staking payout: [rewardPerPercHeld] per whole-PERC fraction held.
  static PercAmount rewardForBalance(PercAmount balance) {
    if (!balance.isPositive) return PercAmount.zero;
    final micro = (balance.microUnits * rewardPerPercHeld.microUnits) ~/
        PercChainConstants.centsPerPerc;
    if (micro <= 0) return PercAmount.zero;
    return PercAmount(micro);
  }
}