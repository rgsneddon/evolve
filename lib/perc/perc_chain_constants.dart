import 'package:flutter/foundation.dart';

import 'models/perc_amount.dart';

/// Perccent chain parameters — infinite Chronoflux continuum supply.
class PercChainConstants {
  const PercChainConstants._();

  /// Shared evolutionary blockchain — every app version connects here.
  static const String evolutionaryChainId = 'evolve-chronoflux-principia-chain-1';

  /// Chronoflux Principia — mechanical foundation for chain evolution.
  static const String chronofluxPrincipiaId = 'chronoflux-principia-roy-d-herbert';

  static const String chainId = 'perc-main-evolve-1';
  static const String sideChainId = 'perc-chronoflux-side-1';
  static const String currencySymbol = 'PERC';
  static const String currencyName = 'Perccent';
  static const String centName = 'cent';
  static const String centValueInPerc = '0.00000001';
  static const int centsPerPerc = 100000000;

  /// Side-chain microblocks seal a main block at 100M (scenario-driven, not analysis keystrokes).
  static const int microblocksPerBlock = 100000000;

  /// Override for tests — never set in production code.
  @visibleForTesting
  static int? microblocksPerBlockOverride;

  /// Perccent forked from Beam privacy — confidential assets enabled.
  static const bool beamPrivacyEnabled = true;

  /// Chronoflux continuum — treasury supply is unbounded.
  static const bool infiniteContinuumSupply = true;

  /// Treasury holder — offline wallet; no external chain until a user runs analysis.
  static const String treasuryUsername = 'rgsneddon';
  static const bool treasuryRequiresExternalChain = false;

  /// One block confirmation fully settles PERC (Chronoflux Principia TIME).
  static const int confirmationsRequired = 1;

  /// Pool renewal allocation per cycle when treasury hits 1 cent reserve.
  static final PercAmount poolRenewalAllocation = PercAmount.fromPerc(283000000);

  /// Minimum treasury reserve — 1 cent (0.00000001 PERC); pool renews at this level.
  static const PercAmount minimumTreasuryReserve = PercAmount(1);

  /// Treasury emits 1 PERC per second — infinite continuum.
  static final PercAmount treasuryEmissionPerSecond = PercAmount.fromPerc(1);

  /// Fixed base faucet payout per scenario analysis.
  static const PercAmount scenarioBaseReward = PercAmount.scenarioBaseReward;

  /// Faucet bonus scales with outcome percent chance (micro-units per 1% point).
  static const int faucetBonusMicroPerPercentPoint = 1;

  /// Each wallet may draw the scenario faucet once per 450 minutes.
  static const Duration faucetCooldown = Duration(minutes: 450);

  /// Cumulative staking: flat 10% of 0.00000050 PERC (0.00000005) per block per holder.
  static const int stakingYieldPercent = 10;

  /// Legacy cap reference — superseded by infinite continuum (display only).
  static final PercAmount legacyCycleAllocation = poolRenewalAllocation;
}