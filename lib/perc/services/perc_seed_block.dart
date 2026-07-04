import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Seed anchor block — advances when cumulative treasury emission crosses 100M PERC.
class PercSeedBlock {
  const PercSeedBlock._();

  /// Whole PERC emitted per seed block (block 2 at 100M, block 3 at 200M, …).
  static const int percPerBlock = PercChainConstants.percPerSeedBlock;

  static int fromTreasuryMinted(PercAmount minted) {
    final thresholdMicro = percPerBlock * PercChainConstants.centsPerPerc;
    if (thresholdMicro <= 0) return 1;
    return (minted.microUnits ~/ thresholdMicro) + 1;
  }
}