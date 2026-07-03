/// Five Chronoflux construct scores (ρt, ω, σ, Iτ, Jμ) at one scenario instant.
class ChronofluxConstructSnapshot {
  const ChronofluxConstructSnapshot({
    required this.continuumScs,
    required this.vortexScs,
    required this.shearScs,
    required this.resistanceScs,
    required this.flowScs,
    required this.timestamp,
    this.outcomeScore,
  });

  final double continuumScs;
  final double vortexScs;
  final double shearScs;
  final double resistanceScs;
  final double flowScs;
  final DateTime timestamp;
  final double? outcomeScore;

  static const inputOrder = [
    'continuum',
    'vortex',
    'shear',
    'resistance',
    'flow',
  ];

  static const symbols = ['ρt', 'ω', 'σ', 'Iτ', 'Jμ'];

  double valueForKey(String key) {
    switch (key) {
      case 'continuum':
        return continuumScs;
      case 'vortex':
        return vortexScs;
      case 'shear':
        return shearScs;
      case 'resistance':
        return resistanceScs;
      case 'flow':
        return flowScs;
      default:
        return continuumScs;
    }
  }

  List<double> get orderedValues =>
      inputOrder.map(valueForKey).toList();

  factory ChronofluxConstructSnapshot.fromCore({
    required double continuumScs,
    required double vortexScs,
    required double shearScs,
    required double resistanceScs,
    required double flowScs,
    required DateTime timestamp,
    double? outcomeScore,
  }) =>
      ChronofluxConstructSnapshot(
        continuumScs: continuumScs.clamp(0, 100),
        vortexScs: vortexScs.clamp(0, 100),
        shearScs: shearScs.clamp(0, 100),
        resistanceScs: resistanceScs.clamp(0, 100),
        flowScs: flowScs.clamp(0, 100),
        timestamp: timestamp,
        outcomeScore: outcomeScore,
      );

  /// Infer five construct points from a stored outcome when legacy txs lack scores.
  factory ChronofluxConstructSnapshot.inferFromOutcome({
    required double outcomeScore,
    required DateTime timestamp,
  }) {
    final base = outcomeScore.clamp(0.0, 100.0);
    return ChronofluxConstructSnapshot(
      continuumScs: base,
      vortexScs: base,
      shearScs: (base * 0.92).clamp(0.0, 100.0),
      resistanceScs: (base * 1.05).clamp(0.0, 100.0),
      flowScs: (100 - base * 0.25).clamp(0.0, 100.0),
      timestamp: timestamp,
      outcomeScore: base,
    );
  }

  Map<String, dynamic> toJson() => {
        'continuumScs': continuumScs,
        'vortexScs': vortexScs,
        'shearScs': shearScs,
        'resistanceScs': resistanceScs,
        'flowScs': flowScs,
        'timestamp': timestamp.toIso8601String(),
        if (outcomeScore != null) 'outcomeScore': outcomeScore,
      };

  factory ChronofluxConstructSnapshot.fromJson(Map<String, dynamic> json) =>
      ChronofluxConstructSnapshot(
        continuumScs: (json['continuumScs'] as num).toDouble(),
        vortexScs: (json['vortexScs'] as num).toDouble(),
        shearScs: (json['shearScs'] as num).toDouble(),
        resistanceScs: (json['resistanceScs'] as num).toDouble(),
        flowScs: (json['flowScs'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        outcomeScore: (json['outcomeScore'] as num?)?.toDouble(),
      );
}