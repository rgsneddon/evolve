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
  static const String treasuryUsername = 'evolve_treasury';
  static const bool treasuryRequiresExternalChain = false;

  /// Default HTTP port for an online Perccent wallet node (bind 0.0.0.0).
  static const int defaultNodePort = 9477;

  /// Optional internet rendezvous for peer discovery + ledger relay (port 9478).
  /// Set in assets/config/perc_network.json or PERC_RENDEZVOUS_URL dart-define.
  static const int defaultRendezvousPort = 9478;

  /// Peer status / ledger gossip timeout.
  static const Duration networkRequestTimeout = Duration(seconds: 8);

  /// One block confirmation fully settles PERC (Chronoflux Principia TIME).
  static const int confirmationsRequired = 1;

  /// Held PERC earns staking only after this many main-chain confirmations.
  static const int stakingConfirmationsRequired = confirmationsRequired;

  /// Pool renewal allocation per cycle when treasury hits 1 cent reserve.
  static final PercAmount poolRenewalAllocation = PercAmount.fromPerc(283000000);

  /// Minimum treasury reserve — 1 cent (0.00000001 PERC); pool renews at this level.
  static const PercAmount minimumTreasuryReserve = PercAmount(1);

  /// Smallest send/receive amount — 1 cent (0.00000001 PERC). All wallets accept this.
  static const PercAmount minimumTransferAmount = PercAmount.smallestUnit;

  /// Network fee on every outbound Perccent transfer — 1 cent (0.00000001 PERC), burned.
  static const PercAmount sendTransactionFee = PercAmount.smallestUnit;

  /// Alias for fee burn semantics across the chain.
  static const PercAmount transactionFeeBurn = sendTransactionFee;

  /// Treasury emits 1 PERC per second — infinite continuum.
  static final PercAmount treasuryEmissionPerSecond = PercAmount.fromPerc(1);

  /// Fixed base faucet payout per scenario analysis.
  static const PercAmount scenarioBaseReward = PercAmount.scenarioBaseReward;

  /// Faucet bonus scales with outcome percent chance (micro-units per 1% point).
  static const int faucetBonusMicroPerPercentPoint = 1;

  /// Each wallet may draw the scenario faucet once per 7 minutes.
  static const Duration faucetCooldown = Duration(minutes: 7);

  /// Offline inbound transfers must be collected by signing in within this
  /// window after they were sent (12 calendar months); otherwise funds revert
  /// to the sender.
  static const Duration walletOnlineReceiveDelay = Duration(days: 365);

  /// Override for tests — never set in production code.
  @visibleForTesting
  static Duration? walletOnlineReceiveDelayOverride;

  static Duration get walletOnlineReceiveDelayEffective =>
      walletOnlineReceiveDelayOverride ?? walletOnlineReceiveDelay;

  /// Cumulative staking: flat 10% of 0.00000050 PERC (0.00000005) per block per holder.
  static const int stakingYieldPercent = 10;

  /// Legacy cap reference — superseded by infinite continuum (display only).
  static final PercAmount legacyCycleAllocation = poolRenewalAllocation;
}