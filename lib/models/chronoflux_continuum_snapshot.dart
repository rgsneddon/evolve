/// Lightweight Chronoflux continuum values for microblock verification.
class ChronofluxContinuumSnapshot {
  const ChronofluxContinuumSnapshot({
    required this.regressivePct,
    required this.refinedScs,
    required this.shearScs,
    required this.continuumPercent,
  });

  final double regressivePct;
  final double refinedScs;
  final double shearScs;
  final double continuumPercent;
}