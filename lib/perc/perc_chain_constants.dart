import 'package:flutter/foundation.dart';

import 'models/perc_amount.dart';

/// Perccent chain parameters — treasury cap 283M PERC; offline until scenarios run.
class PercChainConstants {
  const PercChainConstants._();

  static const String chainId = 'perc-main-evolve-1';
  static const String currencySymbol = 'PERC';
  static const String currencyName = 'Perccent';
  static const String centName = 'cent';
  static const String centValueInPerc = '0.00000001';
  static const int centsPerPerc = 100000000;

  /// Keystrokes advance one microblock; 100M microblocks seal a block.
  static const int microblocksPerBlock = 100000000;

  /// Override for tests — never set in production code.
  @visibleForTesting
  static int? microblocksPerBlockOverride;

  /// Treasury holder — offline wallet; no external chain until a user runs analysis.
  static const String treasuryUsername = 'rgsneddon';
  static const bool treasuryRequiresExternalChain = false;

  /// One block confirmation fully settles PERC.
  static const int confirmationsRequired = 1;

  /// Max supply / pool renewal mint — 283 million PERC.
  static final PercAmount maxSupply = PercAmount.fromPerc(283000000);

  /// Minimum treasury reserve — 1 cent (0.00000001 PERC); pool renews at this level.
  static const PercAmount minimumTreasuryReserve = PercAmount(1);

  /// Treasury emits 1 PERC per second until max supply.
  static final PercAmount treasuryEmissionPerSecond = PercAmount.fromPerc(1);

  /// Fixed base faucet payout per scenario analysis.
  static const PercAmount scenarioBaseReward = PercAmount.scenarioBaseReward;

  /// Faucet bonus scales with outcome percent chance (micro-units per 1% point).
  static const int faucetBonusMicroPerPercentPoint = 1;

  /// Each wallet may draw the scenario faucet once per 450 minutes.
  static const Duration faucetCooldown = Duration(minutes: 450);

  /// Cumulative staking: flat 10% of 0.00000050 PERC (0.00000005) per block per holder.
  static const int stakingYieldPercent = 10;
}