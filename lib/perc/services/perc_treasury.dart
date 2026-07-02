import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Treasury emission — 1 PERC/second until ~286M cumulative mint (Beam-inspired).
class PercTreasury {
  PercTreasury({
    PercAmount? cumulativeMinted,
    PercAmount? poolBalance,
    DateTime? lastTick,
  })  : cumulativeMinted = cumulativeMinted ?? PercAmount.zero,
        poolBalance = poolBalance ?? PercAmount.zero,
        lastTick = lastTick ?? DateTime.now().toUtc();

  /// Total PERC ever minted toward the supply cap.
  PercAmount cumulativeMinted;

  /// Available in treasury for faucet payouts.
  PercAmount poolBalance;
  DateTime lastTick;

  PercAmount get remainingSupply =>
      PercChainConstants.maxSupply - cumulativeMinted;

  bool get isCapped =>
      cumulativeMinted >= PercChainConstants.maxSupply;

  double get emissionProgress =>
      cumulativeMinted.asPerc / PercChainConstants.maxSupply.asPerc;

  /// Advance treasury by elapsed whole seconds; returns amount emitted this tick.
  PercAmount tick([DateTime? now]) {
    final current = (now ?? DateTime.now()).toUtc();
    if (isCapped) {
      lastTick = current;
      return PercAmount.zero;
    }

    final elapsedSeconds = current.difference(lastTick).inSeconds;
    if (elapsedSeconds <= 0) return PercAmount.zero;

    final perSecond = PercChainConstants.treasuryEmissionPerSecond.microUnits;
    var emission = elapsedSeconds * perSecond;
    final capLeft = remainingSupply.microUnits;
    if (emission > capLeft) emission = capLeft;

    final emitted = PercAmount(emission);
    cumulativeMinted = cumulativeMinted + emitted;
    poolBalance = poolBalance + emitted;
    lastTick = lastTick.add(Duration(seconds: elapsedSeconds));
    return emitted;
  }

  bool canFund(PercAmount payout) => poolBalance >= payout;

  void fundFaucet(PercAmount payout) {
    if (!canFund(payout)) {
      throw StateError('Treasury pool cannot fund faucet payout');
    }
    poolBalance = poolBalance - payout;
  }

  Map<String, dynamic> toJson() => {
        'cumulativeMinted': cumulativeMinted.microUnits,
        'poolBalance': poolBalance.microUnits,
        'totalMinted': cumulativeMinted.microUnits,
        'lastTick': lastTick.toIso8601String(),
      };

  factory PercTreasury.fromJson(Map<String, dynamic> json) {
    final cumulative = json['cumulativeMinted'] as int? ??
        json['totalMinted'] as int? ??
        0;
    return PercTreasury(
      cumulativeMinted: PercAmount(cumulative),
      poolBalance: PercAmount(json['poolBalance'] as int? ?? cumulative),
      lastTick: json['lastTick'] != null
          ? DateTime.parse(json['lastTick'] as String)
          : DateTime.now().toUtc(),
    );
  }
}