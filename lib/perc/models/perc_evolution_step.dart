/// One evolutionary step — an app version joining the Chronoflux Principia chain.
class PercEvolutionStep {
  const PercEvolutionStep({
    required this.appVersion,
    required this.timestamp,
    required this.chronofluxFingerprint,
    required this.blockHeight,
    required this.microblockHeight,
    required this.evolutionEpoch,
  });

  final String appVersion;
  final DateTime timestamp;
  final String chronofluxFingerprint;
  final int blockHeight;
  final int microblockHeight;
  final int evolutionEpoch;

  Map<String, dynamic> toJson() => {
        'appVersion': appVersion,
        'timestamp': timestamp.toIso8601String(),
        'chronofluxFingerprint': chronofluxFingerprint,
        'blockHeight': blockHeight,
        'microblockHeight': microblockHeight,
        'evolutionEpoch': evolutionEpoch,
      };

  factory PercEvolutionStep.fromJson(Map<String, dynamic> json) =>
      PercEvolutionStep(
        appVersion: json['appVersion'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        chronofluxFingerprint: json['chronofluxFingerprint'] as String,
        blockHeight: json['blockHeight'] as int? ?? 0,
        microblockHeight: json['microblockHeight'] as int? ?? 0,
        evolutionEpoch: json['evolutionEpoch'] as int? ?? 1,
      );
}