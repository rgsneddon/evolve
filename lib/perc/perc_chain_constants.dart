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

  /// Explorer wards — each ward bundles 10,000 microblocks (10,000 wards per seal cycle).
  static const int microblocksPerWard = 10000;

  /// Override for tests — never set in production code.
  @visibleForTesting
  static int? microblocksPerWardOverride;

  static int get microblocksPerWardEffective =>
      microblocksPerWardOverride ?? microblocksPerWard;

  /// Each wallet accrues one progressive scenario block per concluded analysis (max 100M).
  static const int maxScenarioBlocksPerWallet = 100000000;

  /// Seed anchor advances by one block per 100M PERC treasury emission.
  static const int percPerSeedBlock = 100000000;

  /// Override for tests — never set in production code.
  @visibleForTesting
  static int? microblocksPerBlockOverride;

  /// Perccent forked from Beam privacy — confidential assets enabled.
  static const bool beamPrivacyEnabled = true;

  /// Chronoflux continuum — treasury supply is unbounded.
  static const bool infiniteContinuumSupply = true;

  /// Treasury holder — offline wallet; no external chain until a user runs analysis.
  static const String treasuryUsername = 'evolve_treasury';

  /// Internet seed node — canonical chain anchor on the rendezvous host.
  static const String seedUsername = 'evolve_seed_node';
  static const bool treasuryRequiresExternalChain = false;

  /// Default HTTP port for an online Perccent wallet node (bind 0.0.0.0).
  static const int defaultNodePort = 9477;

  /// Optional internet rendezvous for peer discovery + ledger relay (port 9478).
  /// Set in assets/config/perc_network.json or PERC_RENDEZVOUS_URL dart-define.
  static const int defaultRendezvousPort = 9478;

  /// Peer status / ledger gossip timeout.
  static const Duration networkRequestTimeout = Duration(seconds: 8);

  /// Active wallets poll the seed rendezvous this often for inbound transfers.
  static const Duration walletSeedPollInterval = Duration(seconds: 3);

  /// Seed treats a wallet as online while its heartbeat is newer than this (7 min).
  static const Duration peerOnlineWindow = Duration(minutes: 7);

  /// One block confirmation fully settles PERC (Chronoflux Principia TIME).
  static const int confirmationsRequired = 1;

  /// Held PERC earns staking only after this many main-chain confirmations.
  static const int stakingConfirmationsRequired = confirmationsRequired;

  /// Legacy finite-pool renewal (only when [infiniteContinuumSupply] is false).
  static final PercAmount poolRenewalAllocation = PercAmount.fromPerc(283000000);

  /// Minimum treasury reserve — 1 cent (0.00000001 PERC); staking and faucet debits stop here.
  static const PercAmount minimumTreasuryReserve = PercAmount(1);

  /// Max analysis faucet payout per draw (100/100 PERC).
  static final PercAmount maxFaucetPayoutPerDraw = PercAmount.fromPerc(1);

  /// Treasury accrues one max faucet draw per wallet cooldown window.
  static PercAmount get treasuryEmissionPerCooldown => maxFaucetPayoutPerDraw;

  /// Regeneration ratio — treasury tops up when balance falls below 66% of [treasuryEmissionPerMinute].
  static const int treasuryRegenerationRatioPercent = 66;

  /// Display threshold — 66% of the per-minute emission target.
  static PercAmount get treasuryRegenerationThreshold => PercAmount(
        (treasuryEmissionPerMinute.microUnits *
                treasuryRegenerationRatioPercent) ~/
            100,
      );

  /// True when [balanceMicro] is below the regeneration ratio of the emission target.
  static bool treasuryBalanceNeedsRegeneration(int balanceMicro) =>
      balanceMicro * 100 <
      treasuryEmissionPerMinute.microUnits * treasuryRegenerationRatioPercent;

  /// Smallest send/receive amount — 1 cent (0.00000001 PERC). All wallets accept this.
  static const PercAmount minimumTransferAmount = PercAmount.smallestUnit;

  /// Network fee on every outbound Perccent transfer — 1 cent (0.00000001 PERC), burned.
  static const PercAmount sendTransactionFee = PercAmount.smallestUnit;

  /// Alias for fee burn semantics across the chain.
  static const PercAmount transactionFeeBurn = sendTransactionFee;

  /// One-time genesis mint when the seed treasury launches the blockchain.
  static final PercAmount treasuryLaunchAllocation = PercAmount.fromPerc(1);

  /// Treasury emission per minute — one max faucet draw per [faucetCooldown] window.
  static PercAmount get treasuryEmissionPerMinute {
    final cooldownSec = faucetCooldown.inSeconds;
    if (cooldownSec <= 0) return treasuryEmissionPerCooldown;
    final micro = (treasuryEmissionPerCooldown.microUnits * 60) ~/ cooldownSec;
    return PercAmount(micro);
  }

  /// Fixed eight-decimal label for treasury emission rate (e.g. 0.14285714).
  static String get treasuryEmissionPerMinuteLabel =>
      treasuryEmissionPerMinute.displayFixed8;

  /// Accrued treasury emission for [elapsedSeconds] toward [treasuryEmissionPerCooldown].
  static PercAmount emissionForElapsedSeconds(int elapsedSeconds) {
    if (elapsedSeconds <= 0) return PercAmount.zero;
    final cooldownSec = faucetCooldown.inSeconds;
    if (cooldownSec <= 0) return PercAmount.zero;
    final micro =
        (treasuryEmissionPerCooldown.microUnits * elapsedSeconds) ~/ cooldownSec;
    return PercAmount(micro);
  }

  /// Fixed base faucet payout per scenario analysis.
  static const PercAmount scenarioBaseReward = PercAmount.scenarioBaseReward;

  /// Faucet bonus scales with outcome percent chance (micro-units per 1% point).
  static const int faucetBonusMicroPerPercentPoint = 1;

  /// Each wallet may draw the scenario faucet once per 7 minutes.
  static const Duration faucetCooldown = Duration(minutes: 7);

  /// Auto-logout only after this session age AND [walletSessionIdleTimeout] idle.
  static const Duration walletSessionMaxDuration = Duration(minutes: 8);

  /// No user wallet actions for this long triggers dormancy logout (with max duration).
  static const Duration walletSessionIdleTimeout = Duration(minutes: 7);

  /// Override for tests — never set in production code.
  @visibleForTesting
  static Duration? walletSessionMaxDurationOverride;

  /// Override for tests — never set in production code.
  @visibleForTesting
  static Duration? walletSessionIdleTimeoutOverride;

  static Duration get walletSessionMaxDurationEffective =>
      walletSessionMaxDurationOverride ?? walletSessionMaxDuration;

  static Duration get walletSessionIdleTimeoutEffective =>
      walletSessionIdleTimeoutOverride ?? walletSessionIdleTimeout;

  /// Safety window before unreceived inbound transfers revert to the sender.
  /// Transfers credit near-instantly on send/relay; this is not a user-facing
  /// receive wait.
  static const Duration walletOnlineReceiveDelay = Duration(days: 7);

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