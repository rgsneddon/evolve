import 'models/perc_amount.dart';

/// PERCENTAGE chain parameters — Beam-inspired treasury cap (~286M PERC).
class PercChainConstants {
  const PercChainConstants._();

  static const String chainId = 'perc-main-evolve-1';
  static const String currencySymbol = 'PERC';
  static const String currencyName = 'PERCENTAGE';

  /// Treasury holder — receives all scenario-driven emissions.
  static const String treasuryUsername = 'rgsneddon';

  /// Max supply ~286 million PERC (user spec; Beam uses ~262.8M).
  static final PercAmount maxSupply = PercAmount.fromPerc(286000000);

  /// Treasury emits 1 PERC per second until max supply.
  static final PercAmount treasuryEmissionPerSecond = PercAmount.fromPerc(1);

  /// Fixed base faucet payout per scenario analysis.
  static const PercAmount scenarioBaseReward = PercAmount.scenarioBaseReward;

  /// Faucet bonus scales with outcome percent chance (micro-units per 1% point).
  static const int faucetBonusMicroPerPercentPoint = 1;
}