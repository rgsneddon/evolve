import 'chronoflux_principia_snapshot.dart';

/// Lightweight Chronoflux continuum values for microblock verification.
class ChronofluxContinuumSnapshot {
  const ChronofluxContinuumSnapshot({
    required this.regressivePct,
    required this.refinedScs,
    required this.shearScs,
    required this.continuumPercent,
    this.principia,
  });

  final double regressivePct;
  final double refinedScs;
  final double shearScs;
  final double continuumPercent;

  /// Tweet-core identities on this continuum sample (live fields).
  final ChronofluxPrincipiaSnapshot? principia;
}