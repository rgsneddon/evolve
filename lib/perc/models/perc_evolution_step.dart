/// One evolutionary step — an app version joining the Chronoflux Principia chain.
class PercEvolutionStep {
  const PercEvolutionStep({
    required this.appVersion,
    required this.timestamp,
    required this.chronofluxFingerprint,
    required this.blockHeight,
    required this.microblockHeight,
    required this.evolutionEpoch,
    this.previousAppVersion = '',
    this.parentChronofluxFingerprint = '',
  });

  final String appVersion;
  final DateTime timestamp;
  final String chronofluxFingerprint;
  final int blockHeight;
  final int microblockHeight;
  final int evolutionEpoch;
  /// Prior app release this upgrade linked from (continuity chain).
  final String previousAppVersion;
  /// Fingerprint of the parent evolution step, when available.
  final String parentChronofluxFingerprint;

  bool get hasParentLink =>
      previousAppVersion.isNotEmpty || parentChronofluxFingerprint.isNotEmpty;

  PercEvolutionStep copyWith({
    String? appVersion,
    DateTime? timestamp,
    String? chronofluxFingerprint,
    int? blockHeight,
    int? microblockHeight,
    int? evolutionEpoch,
    String? previousAppVersion,
    String? parentChronofluxFingerprint,
  }) =>
      PercEvolutionStep(
        appVersion: appVersion ?? this.appVersion,
        timestamp: timestamp ?? this.timestamp,
        chronofluxFingerprint: chronofluxFingerprint ?? this.chronofluxFingerprint,
        blockHeight: blockHeight ?? this.blockHeight,
        microblockHeight: microblockHeight ?? this.microblockHeight,
        evolutionEpoch: evolutionEpoch ?? this.evolutionEpoch,
        previousAppVersion: previousAppVersion ?? this.previousAppVersion,
        parentChronofluxFingerprint:
            parentChronofluxFingerprint ?? this.parentChronofluxFingerprint,
      );

  Map<String, dynamic> toJson() => {
        'appVersion': appVersion,
        'timestamp': timestamp.toIso8601String(),
        'chronofluxFingerprint': chronofluxFingerprint,
        'blockHeight': blockHeight,
        'microblockHeight': microblockHeight,
        'evolutionEpoch': evolutionEpoch,
        if (previousAppVersion.isNotEmpty)
          'previousAppVersion': previousAppVersion,
        if (parentChronofluxFingerprint.isNotEmpty)
          'parentChronofluxFingerprint': parentChronofluxFingerprint,
      };

  factory PercEvolutionStep.fromJson(Map<String, dynamic> json) =>
      PercEvolutionStep(
        appVersion: json['appVersion'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        chronofluxFingerprint: json['chronofluxFingerprint'] as String,
        blockHeight: json['blockHeight'] as int? ?? 0,
        microblockHeight: json['microblockHeight'] as int? ?? 0,
        evolutionEpoch: json['evolutionEpoch'] as int? ?? 1,
        previousAppVersion: '${json['previousAppVersion'] ?? ''}',
        parentChronofluxFingerprint:
            '${json['parentChronofluxFingerprint'] ?? ''}',
      );
}