import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Analysis faucet — credits xx/100 PERC from treasury where xx is the
/// two-digit outcome (percent chance or refined SCS, 0–100).
class PercFaucet {
  const PercFaucet._();

  static PercFaucetReward computeScenarioReward({
    required double percentChance,
  }) =>
      computeAnalysisReward(outcomeScore: percentChance);

  static PercFaucetReward computeAnalysisReward({
    required double outcomeScore,
  }) {
    final pct = outcomeScore.clamp(0.0, 100.0);
    final twoDigit = pct.round().clamp(0, 100);
    final total = PercAmount.fromPerc(twoDigit / 100);
    return PercFaucetReward(
      base: PercAmount.zero,
      bonus: total,
      percentChance: pct,
      twoDigitOutcome: twoDigit,
      total: total,
    );
  }
}

class PercFaucetReward {
  const PercFaucetReward({
    required this.base,
    required this.bonus,
    required this.percentChance,
    required this.total,
    required this.twoDigitOutcome,
  });

  final PercAmount base;
  final PercAmount bonus;
  final double percentChance;
  final PercAmount total;
  /// Rounded outcome used for xx/100 PERC (percent chance or SCS).
  final int twoDigitOutcome;

  String get outcomeFractionLabel => '$twoDigitOutcome/100';
}