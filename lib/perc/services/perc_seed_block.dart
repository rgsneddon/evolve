import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Treasury emission milestone tiers and real chain height helpers.
class PercSeedBlock {
  const PercSeedBlock._();

  /// Whole PERC emitted per treasury milestone (milestone 2 at 100M, …).
  static const int percPerBlock = PercChainConstants.percPerSeedBlock;

  /// Treasury emission milestone for display — not main-chain tip height.
  static int treasuryEmissionMilestone(PercAmount minted) {
    final thresholdMicro = percPerBlock * PercChainConstants.centsPerPerc;
    if (thresholdMicro <= 0) return 0;
    return (minted.microUnits ~/ thresholdMicro) + 1;
  }

  /// Real main-chain tip height from block count (0 at fresh genesis).
  static int chainHeightFromBlockCount(int blockCount) => blockCount;

  /// @deprecated Prefer [treasuryEmissionMilestone] for emission tiers.
  static int fromTreasuryMinted(PercAmount minted) =>
      treasuryEmissionMilestone(minted);
}