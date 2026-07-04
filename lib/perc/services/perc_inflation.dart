import '../models/perc_amount.dart';
import '../models/perc_block.dart';
import '../perc_chain_constants.dart';
import 'perc_staking.dart';

/// Treasury inflation — epoch marks each emission block to evolve_treasury.
class PercInflation {
  const PercInflation._();

  /// Pool at minimum reserve (1 cent); next scenario mints a fresh 283M allocation.
  static PercAmount get criticalPoolThreshold =>
      PercChainConstants.minimumTreasuryReserve;

  static bool isPoolCritical(PercAmount treasuryPool) =>
      treasuryPool.microUnits == criticalPoolThreshold.microUnits;

  static bool isPoolAtReserve(PercAmount treasuryPool) =>
      isPoolCritical(treasuryPool);

  /// Balance below 0.66 PERC — treasury should regenerate toward 1 PERC.
  static bool needsRegeneration(PercAmount treasuryPool) =>
      treasuryPool.microUnits <
      PercChainConstants.treasuryRegenerationThreshold.microUnits;

  /// Last block that minted PERC to the treasury (inflationary epoch).
  static DateTime? lastInflationEpoch(List<PercBlock> blocks) {
    for (var i = blocks.length - 1; i >= 0; i--) {
      if (blocks[i].treasuryEmitted.isPositive) return blocks[i].timestamp;
    }
    return null;
  }

  /// Countdown until another 1 PERC accrues at 1 PERC/second since last epoch.
  static Duration? timeToNextInflation({
    required DateTime? lastInflationEpoch,
    required bool blockchainLaunched,
    required bool treasuryCapped,
    required PercAmount treasuryPool,
    required DateTime now,
  }) {
    if (!blockchainLaunched) return null;
    if (needsRegeneration(treasuryPool) ||
        isPoolCritical(treasuryPool) ||
        treasuryCapped) {
      return Duration.zero;
    }
    if (lastInflationEpoch == null) return Duration.zero;

    final elapsedMs = now.difference(lastInflationEpoch).inMilliseconds;
    final remMs = 1000 - (elapsedMs % 1000);
    if (remMs >= 1000) return Duration.zero;
    return Duration(milliseconds: remMs);
  }

  static bool isInflationReady(Duration? timeToNext) =>
      timeToNext == null || timeToNext <= Duration.zero;

  static String formatCountdown(Duration d) {
    if (d <= Duration.zero) return '0s';
    if (d.inMinutes > 0) {
      final s = d.inSeconds % 60;
      return '${d.inMinutes}m ${s}s';
    }
    if (d.inSeconds > 0) return '${d.inSeconds}s';
    return '${d.inMilliseconds}ms';
  }

  static String formatEpoch(DateTime epoch) {
    final local = epoch.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }
}