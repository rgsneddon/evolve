import '../l10n/localized_output.dart';
import '../models/forecast_result.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'base_rate_service.dart';
import 'event_classifier.dart';
import 'outcome_feasibility.dart';

/// Blends historical base rates with Chronoflux heuristic outputs.
class ForecastCalibrator {
  const ForecastCalibrator({
    this.classifier = const EventClassifier(),
    this.baseRates = const BaseRateService(),
    this.baseWeight = 0.6,
    this.heuristicWeight = 0.4,
  });

  final EventClassifier classifier;
  final BaseRateService baseRates;
  final double baseWeight;
  final double heuristicWeight;

  ForecastResult calibrate({
    required ScenarioInput input,
    required LocaleConfig locale,
    required double heuristicPercent,
    required HydrodynamicCore core,
    required LocalizedOutput output,
    OutcomeFeasibility feasibility = const OutcomeFeasibility.open(),
  }) {
    if (feasibility.isForeclosed) {
      final classification = classifier.classify(input, regionId: locale.regionId);
      final pct = OutcomeFeasibility.foreclosedPercent.round();
      final line = output.forecastLineForeclosed(
        pct: pct,
        subject: classification.displayEvent,
        reason: feasibility.reason ?? 'Outcome no longer achievable',
      );
      return ForecastResult(
        calibratedPercent: OutcomeFeasibility.foreclosedPercent,
        heuristicPercent: OutcomeFeasibility.foreclosedPercent,
        baseRatePercent: 0,
        baseCiLow: 0,
        baseCiHigh: 0,
        ciLow: OutcomeFeasibility.foreclosedCiLow,
        ciHigh: OutcomeFeasibility.foreclosedCiHigh,
        horizonDays: classification.horizonDays,
        eventClass: classification.eventClass,
        regionId: locale.regionId,
        sampleSize: 0,
        successCount: 0,
        brierScore: 0,
        provenance: 'settled outcome',
        yearMin: 0,
        yearMax: 0,
        matchedCaseLines: const [],
        forecastLine: line,
      );
    }

    final classification = classifier.classify(input, regionId: locale.regionId);
    final base = baseRates.lookup(
      eventClass: classification.eventClass,
      regionId: locale.regionId,
      horizonDays: classification.horizonDays,
    );

    final calibrated = (baseWeight * base.ratePercent +
            heuristicWeight * heuristicPercent)
        .clamp(8.0, 92.0)
        .toDouble();

    final ciLow = (baseWeight * base.ciLow +
            heuristicWeight * (heuristicPercent - 10))
        .clamp(8, 92)
        .round();
    final ciHigh = (baseWeight * base.ciHigh +
            heuristicWeight * (heuristicPercent + 10))
        .clamp(8, 92)
        .round();

    final provenance = base.sources.join(', ');
    final matchedCaseLines = base.matchedRecords
        .map((r) => r.caseLabel(output))
        .toList(growable: false);
    final line = output.forecastLine(
      pct: calibrated.round(),
      ciLow: ciLow,
      ciHigh: ciHigh,
      subject: classification.displayEvent,
      horizonDays: classification.horizonDays,
      sampleSize: base.sampleSize,
      yearMin: base.yearMin,
      yearMax: base.yearMax,
      brier: base.brierScore,
      refinedScs: core.refinedScs.round(),
      regressivePct: core.regressivePct,
      provenance: provenance,
    );

    return ForecastResult(
      calibratedPercent: calibrated,
      heuristicPercent: heuristicPercent,
      baseRatePercent: base.ratePercent,
      baseCiLow: base.ciLow,
      baseCiHigh: base.ciHigh,
      ciLow: ciLow,
      ciHigh: ciHigh,
      horizonDays: classification.horizonDays,
      eventClass: classification.eventClass,
      regionId: locale.regionId,
      sampleSize: base.sampleSize,
      successCount: base.successCount,
      brierScore: base.brierScore,
      provenance: provenance,
      yearMin: base.yearMin,
      yearMax: base.yearMax,
      matchedCaseLines: matchedCaseLines,
      forecastLine: line,
    );
  }
}