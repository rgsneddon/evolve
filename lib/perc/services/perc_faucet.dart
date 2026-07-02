import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Scenario faucet — base reward + percent-chance bonus from treasury.
class PercFaucet {
  const PercFaucet._();

  static PercFaucetReward computeScenarioReward({
    required double percentChance,
  }) {
    final pct = percentChance.clamp(0.0, 100.0);
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