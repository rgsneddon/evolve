/// One pathway/item from a multi-part percent-chance question.
class PartPercentResult {
  const PartPercentResult({
    required this.label,
    required this.subQuestion,
    required this.percentChance,
    required this.percentPhrase,
    required this.lean,
    this.rawCalibratedPercent = 0,
    this.regressivePct = 0,
    this.progressivePct = 0,
    this.continuumMomentum = 0,
  });

  final String label;
  final String subQuestion;
  /// Normalized outcome share — all pathway shares sum to 100%.
  final double percentChance;
  final String percentPhrase;
  final String lean;
  final double rawCalibratedPercent;
  final double regressivePct;
  final double progressivePct;
  final double continuumMomentum;

  bool get isRegressive => lean == 'REGRESSIVE';
}

/// Listed per-item percent chances for a multi-part posed question.
class PartPercentBreakdown {
  const PartPercentBreakdown({
    required this.outcomeContext,
    required this.parts,
  });

  final String outcomeContext;
  final List<PartPercentResult> parts;

  bool get isEmpty => parts.isEmpty;
  bool get isNotEmpty => parts.isNotEmpty;

  int get partitionTotal =>
      parts.fold<int>(0, (sum, p) => sum + p.percentChance.round());
}