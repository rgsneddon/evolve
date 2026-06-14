import 'dart:math' as math;

import '../data/outcome_registry.dart';
import '../models/outcome_record.dart';

class BaseRateLookup {
  const BaseRateLookup({
    required this.ratePercent,
    required this.ciLow,
    required this.ciHigh,
    required this.sampleSize,
    required this.brierScore,
    required this.sources,
    required this.yearMin,
    required this.yearMax,
    required this.matchedRecords,
    required this.successCount,
  });

  final double ratePercent;
  final double ciLow;
  final double ciHigh;
  final int sampleSize;
  final double brierScore;
  final List<String> sources;
  final int yearMin;
  final int yearMax;
  final List<OutcomeRecord> matchedRecords;
  final int successCount;
}

/// Historical base-rate lookup from the Outcome Registry.
class BaseRateService {
  const BaseRateService({this.registry});

  final OutcomeRegistry? registry;

  OutcomeRegistry get _registry => registry ?? OutcomeRegistry.bundled();

  BaseRateLookup lookup({
    required String eventClass,
    required String regionId,
    required int horizonDays,
  }) {
    final hits = _registry.matchingWithFallback(
      eventClass: eventClass,
      regionId: regionId,
      horizonDays: horizonDays,
    );

    if (hits.isEmpty) {
      return const BaseRateLookup(
        ratePercent: 35,
        ciLow: 22,
        ciHigh: 48,
        sampleSize: 0,
        brierScore: 0.24,
        sources: ['Chronoflux seed'],
        yearMin: 2010,
        yearMax: 2025,
        matchedRecords: [],
        successCount: 0,
      );
    }

    final successes = hits.where((r) => r.occurred).length;
    final n = hits.length;
    final rate = successes / n * 100;
    final ci = _wilsonInterval(successes, n);
    final brier = _brierScore(hits, rate / 100);
    final sources = hits.map((r) => r.source).toSet().toList()..sort();
    final years = hits.map((r) => r.yearPosed);

    return BaseRateLookup(
      ratePercent: rate.clamp(5, 95),
      ciLow: (ci.low * 100).clamp(5, 95),
      ciHigh: (ci.high * 100).clamp(5, 95),
      sampleSize: n,
      brierScore: brier,
      sources: sources,
      yearMin: years.reduce(math.min),
      yearMax: years.reduce(math.max),
      matchedRecords: List<OutcomeRecord>.from(hits)
        ..sort((a, b) {
          final year = a.yearPosed.compareTo(b.yearPosed);
          if (year != 0) return year;
          return a.id.compareTo(b.id);
        }),
      successCount: successes,
    );
  }

  static ({double low, double high}) _wilsonInterval(int successes, int n,
      {double z = 1.96}) {
    if (n == 0) return (low: 0.08, high: 0.92);
    final p = successes / n;
    final z2 = z * z;
    final denom = 1 + z2 / n;
    final center = p + z2 / (2 * n);
    final margin = z * math.sqrt((p * (1 - p) + z2 / (4 * n)) / n);
    return (
      low: ((center - margin) / denom).clamp(0.0, 1.0),
      high: ((center + margin) / denom).clamp(0.0, 1.0),
    );
  }

  static double _brierScore(List<OutcomeRecord> hits, double predictedRate) {
    if (hits.isEmpty) return 0.24;
    var sum = 0.0;
    for (final r in hits) {
      final actual = r.occurred ? 1.0 : 0.0;
      final err = predictedRate - actual;
      sum += err * err;
    }
    return sum / hits.length;
  }
}