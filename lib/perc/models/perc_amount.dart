/// PERCENTAGE (PERC) — 8 decimal places; 1 PERC = 100_000_000 micro-units.
class PercAmount {
  const PercAmount(this.microUnits);

  static const int decimals = 8;
  static const int unitsPerPerc = 100000000;

  final int microUnits;

  static const zero = PercAmount(0);

  bool get isPositive => microUnits > 0;

  Map<String, dynamic> toJson() => {'microUnits': microUnits};

  static PercAmount fromJson(Map<String, dynamic> json) =>
      PercAmount(json['microUnits'] as int? ?? json['balance'] as int? ?? 0);

  /// Fixed reward per completed scenario: 0.00000050 PERC.
  static const scenarioBaseReward = PercAmount(50);

  static PercAmount fromPerc(double perc) =>
      PercAmount((perc * unitsPerPerc).round());

  static PercAmount? tryParseDisplay(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return fromPerc(value);
  }

  double get asPerc => microUnits / unitsPerPerc;

  String get display {
    final whole = microUnits ~/ unitsPerPerc;
    final frac = microUnits % unitsPerPerc;
    if (frac == 0) return '$whole';
    final fracStr = frac.toString().padLeft(decimals, '0');
    final trimmed = fracStr.replaceFirst(RegExp(r'0+$'), '');
    return '$whole.${trimmed.isEmpty ? '0' : trimmed}';
  }

  String get displayFixed8 {
    final whole = microUnits ~/ unitsPerPerc;
    final frac = (microUnits % unitsPerPerc).toString().padLeft(decimals, '0');
    return '$whole.$frac';
  }

  PercAmount operator +(PercAmount other) =>
      PercAmount(microUnits + other.microUnits);

  PercAmount operator -(PercAmount other) =>
      PercAmount(microUnits - other.microUnits);

  PercAmount operator *(int factor) => PercAmount(microUnits * factor);

  bool operator <(PercAmount other) => microUnits < other.microUnits;
  bool operator >(PercAmount other) => microUnits > other.microUnits;
  bool operator <=(PercAmount other) => microUnits <= other.microUnits;
  bool operator >=(PercAmount other) => microUnits >= other.microUnits;

  @override
  bool operator ==(Object other) =>
      other is PercAmount && other.microUnits == microUnits;

  @override
  int get hashCode => microUnits.hashCode;
}