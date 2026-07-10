import '../perc/perc_chain_constants.dart';

/// Conservative defaults to keep CPU use low on laptops and desktops.
class AppPerformance {
  const AppPerformance._();

  static const Duration bannerLoopDuration = Duration(seconds: 48);
  static const Duration foregroundNetworkPoll =
      PercChainConstants.walletSeedPollInterval;
  static const Duration backgroundNetworkPoll = Duration(seconds: 120);
  /// Rapid inbound relay pickup while foregrounded (after PUT hint, tab focus, resume).
  static const Duration inboundBurstPollInterval = Duration(milliseconds: 400);
  static const int inboundBurstMaxAttempts = 12;
  static const Duration inboundBurstCooldown = Duration(seconds: 2);
  static const Duration walletInflationTick = Duration(seconds: 5);

  /// Explorer shard field resolution (lower = less paint work per frame).
  static const int shardAngularBins = 120;
  static const int shardRadialBins = 80;
}