import 'dart:math' as math;

import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';
import 'perc_block_timing.dart';
import 'perc_ledger.dart';

/// Inputs for scaling treasury emission with chain activity and wallet load.
class PercEmissionContext {
  const PercEmissionContext({
    required this.walletCount,
    required this.onlineWalletCount,
    required this.averageBlockTime,
  });

  final int walletCount;
  final int onlineWalletCount;
  final Duration? averageBlockTime;
}

/// Treasury emission scaled by average block time and active wallet load.
class PercDynamicEmission {
  const PercDynamicEmission._();

  /// Baseline load at 1.0× (solo wallet, reference block pace).
  static const int referenceWalletCount = 1;

  /// Minimum combined multiplier (50%).
  static const int minCombinedFactorPercent = 50;

  /// Maximum combined multiplier (10× baseline).
  static const int maxCombinedFactorPercent = 1000;

  static PercEmissionContext contextFromLedger(PercLedger ledger) {
    final treasury = PercChainConstants.treasuryUsername;
    final wallets = ledger.accounts.keys
        .where((username) => username != treasury)
        .length;
    final online = ledger.networkNodes.values
        .where((node) => node.online && node.username != treasury)
        .length;
    final loadWallets = math.max(
      wallets > 0 ? wallets : referenceWalletCount,
      online > 0 ? online : referenceWalletCount,
    );

    return PercEmissionContext(
      walletCount: loadWallets,
      onlineWalletCount: online,
      averageBlockTime: PercBlockTiming.averageTimePerBlock(ledger.blocks),
    );
  }

  /// Scales with √(wallet count): 1 wallet → 1.0×, 4 → 2.0×, 25 → 5.0×.
  static int loadFactorPercent(PercEmissionContext context) {
    final wallets = math.max(referenceWalletCount, context.walletCount);
    final raw = (math.sqrt(wallets) * 100).round();
    return raw.clamp(100, maxCombinedFactorPercent);
  }

  /// Faster blocks than the faucet cooldown raise emission; slower blocks lower it.
  static int blockTimeFactorPercent(PercEmissionContext context) {
    final referenceSec = PercChainConstants.faucetCooldown.inSeconds;
    if (referenceSec <= 0) return 100;

    final avg = context.averageBlockTime;
    if (avg == null || avg <= Duration.zero) return 100;

    final avgSec = avg.inSeconds.clamp(1, 86400);
    final raw = (referenceSec * 100) ~/ avgSec;
    return raw.clamp(minCombinedFactorPercent, 500);
  }

  static int combinedFactorPercent(PercEmissionContext context) {
    final load = loadFactorPercent(context);
    final block = blockTimeFactorPercent(context);
    final combined = (load * block) ~/ 100;
    return combined.clamp(minCombinedFactorPercent, maxCombinedFactorPercent);
  }

  static PercAmount effectiveEmissionPerCooldown(PercEmissionContext context) {
    final base = PercChainConstants.treasuryEmissionPerCooldown.microUnits;
    final micro = base * combinedFactorPercent(context) ~/ 100;
    return PercAmount(micro);
  }

  static PercAmount effectiveEmissionPerMinute(PercEmissionContext context) {
    final cooldownSec = PercChainConstants.faucetCooldown.inSeconds;
    if (cooldownSec <= 0) return effectiveEmissionPerCooldown(context);
    final perCooldown = effectiveEmissionPerCooldown(context).microUnits;
    return PercAmount(perCooldown * 60 ~/ cooldownSec);
  }

  static PercAmount emissionForElapsedSeconds(
    int elapsedSeconds,
    PercEmissionContext context,
  ) {
    if (elapsedSeconds <= 0) return PercAmount.zero;
    final cooldownSec = PercChainConstants.faucetCooldown.inSeconds;
    if (cooldownSec <= 0) return PercAmount.zero;
    final perCooldown = effectiveEmissionPerCooldown(context).microUnits;
    return PercAmount(perCooldown * elapsedSeconds ~/ cooldownSec);
  }

  static PercAmount regenerationThreshold(PercEmissionContext context) {
    final target = effectiveEmissionPerMinute(context).microUnits;
    return PercAmount(
      (target * PercChainConstants.treasuryRegenerationRatioPercent) ~/ 100,
    );
  }

  static bool needsRegeneration(int balanceMicro, PercEmissionContext context) {
    final target = effectiveEmissionPerMinute(context).microUnits;
    return balanceMicro * 100 <
        target * PercChainConstants.treasuryRegenerationRatioPercent;
  }
}