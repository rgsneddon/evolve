import '../perc_chain_constants.dart';

/// Perccent (PERC) — 8 decimal places; 1 PERC = 100_000_000 cent (0.00000001 PERC each).
class PercAmount {
  const PercAmount(this.microUnits);

  static const int decimals = 8;
  static const int unitsPerPerc = PercChainConstants.centsPerPerc;

  final int microUnits;

  static const zero = PercAmount(0);

  /// Smallest transferable unit — 1 cent = 0.00000001 PERC.
  static const smallestUnit = PercAmount(1);

  bool get isPositive => microUnits > 0;

  /// True when [amount] is at least one cent (0.00000001 PERC).
  bool get isAtLeastSmallestUnit => microUnits >= smallestUnit.microUnits;

  Map<String, dynamic> toJson() => {'microUnits': microUnits};

  static PercAmount fromJson(Map<String, dynamic> json) =>
      PercAmount(json['microUnits'] as int? ?? json['balance'] as int? ?? 0);

  /// Fixed reward per completed scenario: 50 cent (0.00000050 PERC).
  static const scenarioBaseReward = PercAmount(50);

  /// Smallest denomination — 1 cent = 0.00000001 PERC.
  int get asCents => microUnits;

  String get centDisplay =>
      '$asCents ${asCents == 1 ? PercChainConstants.centName : '${PercChainConstants.centName}s'}';

  static PercAmount fromPerc(double perc) =>
      PercAmount((perc * unitsPerPerc).round());

  /// Parses a display amount with up to [decimals] fractional digits (no float drift).
  static PercAmount? tryParseDecimalString(String text) {
    var cleaned = text.trim().replaceAll(',', '').replaceAll(' ', '');
    if (cleaned.isEmpty || cleaned.startsWith('-')) return null;

    if (cleaned.startsWith('.')) {
      final fracRaw = cleaned.substring(1);
      if (fracRaw.isEmpty || !RegExp(r'^\d+$').hasMatch(fracRaw)) return null;
      if (fracRaw.length > decimals) return null;
      return PercAmount(int.parse(fracRaw.padRight(decimals, '0')));
    }

    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(cleaned);
    if (match == null) return null;

    final wholePart = int.tryParse(match.group(1)!);
    if (wholePart == null) return null;

    final fracRaw = match.group(2) ?? '';
    if (fracRaw.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fracRaw)) {
      return null;
    }
    if (fracRaw.length > decimals) return null;

    final fracPart =
        fracRaw.isEmpty ? 0 : int.parse(fracRaw.padRight(decimals, '0'));
    return PercAmount(wholePart * unitsPerPerc + fracPart);
  }

  static PercAmount? tryParseDisplay(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final precise = tryParseDecimalString(cleaned);
    if (precise != null) return precise;
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