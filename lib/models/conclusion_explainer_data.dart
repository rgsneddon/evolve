/// Structured construal + registry data for the “How to read this conclusion” panel.
class ConclusionExplainerData {
  const ConclusionExplainerData({
    required this.construalSignals,
    required this.construalConstructs,
    required this.registryFilter,
    required this.registrySummary,
    required this.calibrationSummary,
    required this.matchedCaseLines,
    required this.successCount,
    required this.sampleSize,
  });

  final String construalSignals;
  final String construalConstructs;
  final String registryFilter;
  final String registrySummary;
  final String calibrationSummary;
  final List<String> matchedCaseLines;
  final int successCount;
  final int sampleSize;
}