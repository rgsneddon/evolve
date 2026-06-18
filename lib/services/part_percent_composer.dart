import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/part_percent_breakdown.dart';
import 'package:flutter/foundation.dart';

import 'question_semantics.dart';

/// Draft metrics for one pathway before partition normalization.
class PartPercentDraft {
  const PartPercentDraft({
    required this.label,
    required this.subQuestion,
    required this.rawCalibrated,
    required this.partitionWeight,
    required this.regressivePct,
    required this.progressivePct,
    required this.refinedScs,
    required this.shearScs,
  });

  final String label;
  final String subQuestion;
  final double rawCalibrated;
  final double partitionWeight;
  final double regressivePct;
  final double progressivePct;
  final double refinedScs;
  final double shearScs;

  double get continuumMomentum => regressivePct - progressivePct;

  double get cohesionStrain => (100 - refinedScs).clamp(0, 100);
}

/// Normalizes pathway weights to a 100% partition and assigns relative leans.
class PartPercentComposer {
  const PartPercentComposer._();

  static PartPercentBreakdown compose({
    required List<PartPercentDraft> drafts,
    required String outcomeContext,
    required LocalizedOutput output,
    required LocaleConfig locale,
  }) {
    if (drafts.isEmpty) {
      return PartPercentBreakdown(outcomeContext: outcomeContext, parts: const []);
    }

    final weights = drafts
        .map((d) => d.partitionWeight.clamp(1.0, 100.0))
        .toList(growable: false);
    final shares = _normalizeTo100(_amplifyPartitionSpread(weights));

    final momenta = drafts.map((d) => d.continuumMomentum).toList();
    final meanMomentum =
        momenta.fold(0.0, (a, b) => a + b) / momenta.length;

    final ranked = drafts.asMap().entries.toList()
      ..sort((a, b) => b.value.continuumMomentum.compareTo(a.value.continuumMomentum));

    final regressiveRank = <int, int>{};
    for (var i = 0; i < ranked.length; i++) {
      regressiveRank[ranked[i].key] = i;
    }

    final parts = <PartPercentResult>[];
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      final share = shares[i];
      final lean = _classifyPathwayLean(
        draft: draft,
        normalizedShare: share,
        cohortMeanMomentum: meanMomentum,
        regressiveRank: regressiveRank[i] ?? drafts.length - 1,
        partCount: drafts.length,
      );
      final sem = QuestionSemantics.fromText(
        draft.subQuestion,
        regionId: locale.regionId,
        regionLabel: output.regionName(locale.regionId),
      );

      parts.add(
        PartPercentResult(
          label: draft.label,
          subQuestion: draft.subQuestion,
          percentChance: share.toDouble(),
          rawCalibratedPercent: draft.rawCalibrated,
          percentPhrase: output.partBreakdownSharePhrase(
            share: share,
            pathway: draft.label,
            outcomeContext: outcomeContext,
            frame: sem.frame,
            displaySubject: sem.displaySubject,
          ),
          lean: lean,
          regressivePct: draft.regressivePct,
          progressivePct: draft.progressivePct,
          continuumMomentum: draft.continuumMomentum,
        ),
      );
    }

    parts.sort((a, b) {
      final byShare = b.percentChance.compareTo(a.percentChance);
      if (byShare != 0) return byShare;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    return PartPercentBreakdown(
      outcomeContext: outcomeContext,
      parts: parts,
    );
  }

  @visibleForTesting
  static List<int> normalizeTo100ForTest(List<double> weights) =>
      _normalizeTo100(_amplifyPartitionSpread(weights));

  @visibleForTesting
  static List<double> amplifyPartitionSpreadForTest(List<double> weights) =>
      _amplifyPartitionSpread(weights);

  /// Widens near-equal partition weights so shares reflect pathway divergence.
  static List<double> _amplifyPartitionSpread(List<double> weights) {
    if (weights.length < 2) return weights;

    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    if (maxW - minW < 5) {
      final ranked = weights.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final n = weights.length;
      final spread = List<double>.filled(n, 1);
      for (var r = 0; r < n; r++) {
        spread[ranked[r].key] = (n - r) * (n - r).toDouble();
      }
      return spread;
    }

    final mean = weights.fold(0.0, (a, b) => a + b) / weights.length;
    return weights
        .map((w) => (mean + (w - mean) * 1.9).clamp(1.0, 100.0))
        .toList(growable: false);
  }

  /// Largest-remainder method — integer shares sum exactly to 100.
  static List<int> _normalizeTo100(List<double> weights) {
    if (weights.isEmpty) return const [];
    final total = weights.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      final even = (100 / weights.length).floor();
      final shares = List.filled(weights.length, even);
      var remainder = 100 - shares.fold(0, (a, b) => a + b);
      for (var i = 0; remainder > 0 && i < shares.length; i++, remainder--) {
        shares[i]++;
      }
      return shares;
    }

    final exact = weights.map((w) => w / total * 100).toList();
    final floors = exact.map((e) => e.floor()).toList();
    var remainder = 100 - floors.fold<int>(0, (a, b) => a + b);

    final order = exact.asMap().entries.toList()
      ..sort(
        (a, b) => (b.value - b.value.floor())
            .compareTo(a.value - a.value.floor()),
      );

    for (var i = 0; remainder > 0 && i < order.length; i++, remainder--) {
      floors[order[i].key]++;
    }
    return floors;
  }

  static String _classifyPathwayLean({
    required PartPercentDraft draft,
    required int normalizedShare,
    required double cohortMeanMomentum,
    required int regressiveRank,
    required int partCount,
  }) {
    final momentum = draft.continuumMomentum;
    final strain = draft.cohesionStrain;
    final isMostRegressive = regressiveRank == 0 && partCount > 1;
    final isMostProgressive = regressiveRank == partCount - 1 && partCount > 1;

    if (momentum >= 8 || (isMostRegressive && momentum > 0)) return 'REGRESSIVE';
    if (momentum <= -8 || (isMostProgressive && momentum < 0)) {
      return 'PROGRESSIVE';
    }

    if (normalizedShare >= 35) {
      if (momentum > 2 && strain >= 42) return 'REGRESSIVE';
      if (momentum < -2 || (momentum <= 0 && strain < 48)) return 'PROGRESSIVE';
    }

    if (draft.shearScs >= 58 && momentum >= 0) return 'REGRESSIVE';
    if (draft.shearScs <= 42 && momentum <= 0) return 'PROGRESSIVE';

    if (momentum > cohortMeanMomentum + 2) return 'REGRESSIVE';
    if (momentum < cohortMeanMomentum - 2) return 'PROGRESSIVE';

    return strain >= 50 || momentum >= 0 ? 'REGRESSIVE' : 'PROGRESSIVE';
  }
}