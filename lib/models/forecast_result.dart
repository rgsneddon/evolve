class ForecastResult {
  const ForecastResult({
    required this.calibratedPercent,
    required this.heuristicPercent,
    required this.baseRatePercent,
    required this.baseCiLow,
    required this.baseCiHigh,
    required this.ciLow,
    required this.ciHigh,
    required this.horizonDays,
    required this.eventClass,
    required this.regionId,
    required this.sampleSize,
    required this.successCount,
    required this.brierScore,
    required this.provenance,
    required this.yearMin,
    required this.yearMax,
    required this.matchedCaseLines,
    required this.forecastLine,
  });

  final double calibratedPercent;
  final double heuristicPercent;
  final double baseRatePercent;
  final double baseCiLow;
  final double baseCiHigh;
  final int ciLow;
  final int ciHigh;
  final int horizonDays;
  final String eventClass;
  final String regionId;
  final int sampleSize;
  final int successCount;
  final double brierScore;
  final String provenance;
  final int yearMin;
  final int yearMax;
  final List<String> matchedCaseLines;
  final String forecastLine;
}