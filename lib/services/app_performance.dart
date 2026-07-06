import 'package:flutter/foundation.dart';

/// Conservative defaults to keep CPU use low on laptops and desktops.
class AppPerformance {
  const AppPerformance._();

  /// Splash video decode is skipped on desktop — static poster instead.
  static bool get useLightweightSplash {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  static const Duration bannerLoopDuration = Duration(seconds: 48);
  static const Duration foregroundNetworkPoll = Duration(seconds: 60);
  static const Duration backgroundNetworkPoll = Duration(seconds: 120);
  static const Duration walletInflationTick = Duration(seconds: 5);

  /// Explorer shard field resolution (lower = less paint work per frame).
  static const int shardAngularBins = 120;
  static const int shardRadialBins = 80;
}