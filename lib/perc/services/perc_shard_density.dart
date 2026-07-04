import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../perc_chain_constants.dart';
import 'perc_ward_bundler.dart';

/// Maps Chronoflux ward bundles (10,000 microblocks each) into a polar density field.
class PercShardDensity {
  const PercShardDensity({
    required this.totalShards,
    required this.litShards,
    required this.angularBins,
    required this.radialBins,
    required this.density,
    required this.litDensity,
  });

  final int totalShards;
  final int litShards;
  final int angularBins;
  final int radialBins;
  final List<int> density;
  final List<int> litDensity;

  int get maxDensity {
    var peak = 1;
    for (final v in density) {
      if (v > peak) peak = v;
    }
    return peak;
  }

  int get maxLitDensity {
    var peak = 1;
    for (final v in litDensity) {
      if (v > peak) peak = v;
    }
    return peak;
  }

  static Future<PercShardDensity> build({
    int? totalShards,
    required int litShards,
    int angularBins = 360,
    int radialBins = 280,
  }) async {
    final total = totalShards ?? PercChainConstants.microblocksPerBlock;
    final params = _ShardDensityParams(
      totalShards: total,
      litShards: litShards.clamp(0, total),
      angularBins: angularBins,
      radialBins: radialBins,
    );
    if (kIsWeb || total < 500000) {
      return _buildSync(params);
    }
    return compute(_buildSync, params);
  }

  /// Ward-level field — one shard per ward (10,000 microblocks bundled).
  static Future<PercShardDensity> buildForWards({
    required PercWardView wards,
    int angularBins = 360,
    int radialBins = 280,
  }) =>
      build(
        totalShards: wards.wardsPerSealCycle,
        litShards: wards.completedWardsInCycle,
        angularBins: angularBins,
        radialBins: radialBins,
      );
}

@immutable
class _ShardDensityParams {
  const _ShardDensityParams({
    required this.totalShards,
    required this.litShards,
    required this.angularBins,
    required this.radialBins,
  });

  final int totalShards;
  final int litShards;
  final int angularBins;
  final int radialBins;
}

PercShardDensity _buildSync(_ShardDensityParams params) {
  final bins = params.angularBins * params.radialBins;
  final density = List<int>.filled(bins, 0);
  final litDensity = List<int>.filled(bins, 0);
  final goldenAngle = math.pi * (3 - math.sqrt(5));
  final total = params.totalShards;

  for (var i = 0; i < total; i++) {
    final angle = i * goldenAngle;
    final radius = math.sqrt((i + 0.5) / total);
    final aBin =
        (angle / (math.pi * 2) * params.angularBins).floor() % params.angularBins;
    final rBin =
        (radius * params.radialBins).floor().clamp(0, params.radialBins - 1);
    final idx = rBin * params.angularBins + aBin;
    density[idx]++;
    if (i < params.litShards) {
      litDensity[idx]++;
    }
  }

  return PercShardDensity(
    totalShards: total,
    litShards: params.litShards,
    angularBins: params.angularBins,
    radialBins: params.radialBins,
    density: density,
    litDensity: litDensity,
  );
}