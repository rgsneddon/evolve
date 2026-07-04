/// One fair-usage microblock recorded from app activity (e.g. field keystrokes).
class PercMicroblockLogEntry {
  const PercMicroblockLogEntry({
    required this.index,
    required this.timestamp,
    required this.wardIndex,
    required this.wardMicroblock,
    required this.activity,
    this.label,
    this.continuumPercent,
    this.fingerprint,
    this.blockSealed = false,
  });

  /// Lifetime microblock index (1-based).
  final int index;
  final DateTime timestamp;
  /// Ward index within the current seal cycle (0-based).
  final int wardIndex;
  /// Position within the ward (1-based).
  final int wardMicroblock;
  final String activity;
  final String? label;
  final double? continuumPercent;
  final String? fingerprint;
  final bool blockSealed;

  Map<String, dynamic> toJson() => {
        'index': index,
        'timestamp': timestamp.toIso8601String(),
        'wardIndex': wardIndex,
        'wardMicroblock': wardMicroblock,
        'activity': activity,
        if (label != null && label!.isNotEmpty) 'label': label,
        if (continuumPercent != null) 'continuumPercent': continuumPercent,
        if (fingerprint != null) 'fingerprint': fingerprint,
        if (blockSealed) 'blockSealed': blockSealed,
      };

  factory PercMicroblockLogEntry.fromJson(Map<String, dynamic> json) =>
      PercMicroblockLogEntry(
        index: json['index'] as int? ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        wardIndex: json['wardIndex'] as int? ?? 0,
        wardMicroblock: json['wardMicroblock'] as int? ?? 0,
        activity: json['activity'] as String? ?? 'fair_usage',
        label: json['label'] as String?,
        continuumPercent: (json['continuumPercent'] as num?)?.toDouble(),
        fingerprint: json['fingerprint'] as String?,
        blockSealed: json['blockSealed'] as bool? ?? false,
      );
}