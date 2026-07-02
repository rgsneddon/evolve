import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Analysis faucet — base reward + outcome-score bonus from treasury.
/// [outcomeScore] is percent chance (0–100) or social cohesion score (0–100).
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
    final base = PercChainConstants.scenarioBaseReward;
    final bonusUnits =
        (pct.round() * PercChainConstants.faucetBonusMicroPerPercentPoint)
            .clamp(0, 10000);
    final bonus = PercAmount(bonusUnits);
    return PercFaucetReward(
      base: base,
      bonus: bonus,
      percentChance: pct,
      total: base + bonus,
    );
  }
}

class PercFaucetReward {
  const PercFaucetReward({
    required this.base,
    required this.bonus,
    required this.percentChance,
    required this.total,
  });

  final PercAmount base;
  final PercAmount bonus;
  final double percentChance;
  final PercAmount total;
}