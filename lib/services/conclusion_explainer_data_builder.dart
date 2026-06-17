import '../l10n/localized_output.dart';
import '../models/conclusion_explainer_data.dart';
import '../models/forecast_result.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'chronoflux_weight_construal.dart';
import 'event_classifier.dart';
import 'question_semantics.dart';
import 'scenario_calculation_context.dart';

/// Builds structured explainer data mirroring CONCLUSION — THE CONTINUUM.
class ConclusionExplainerDataBuilder {
  const ConclusionExplainerDataBuilder({
    this.weightConstrual = const ChronofluxWeightConstrual(),
    this.classifier = const EventClassifier(),
    this.baseWeight = 0.6,
    this.heuristicWeight = 0.4,
  });

  final ChronofluxWeightConstrual weightConstrual;
  final EventClassifier classifier;
  final double baseWeight;
  final double heuristicWeight;

  ConclusionExplainerData build({
    required ScenarioInput input,
    required LocaleConfig locale,
    required LocalizedOutput output,
    required ForecastResult forecast,
    required HydrodynamicCore core,
  }) {
    final regionLabel = output.regionName(locale.regionId);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: regionLabel,
    );
    final classification = classifier.classify(input, regionId: locale.regionId);
    final question = input.posedQuestionLine ?? sem.raw;
    final weights = weightConstrual.construeFromContext(
      ScenarioCalculationContext.from(
        input: input,
        regionId: locale.regionId,
      ),
    );
    final wPct = weights.normalized.map((w) => (w * 100).round()).toList();

    final vortexScs = sem.vortexOffset.clamp(38, 82).round();
    final shearScs = sem.shearOffset.clamp(42, 78).round();
    final resistanceScs = sem.resistanceOffset.clamp(40, 74).round();
    final flowScs = sem.flowOffset.clamp(32, 68).round();

    final hints = sem.hintSignals.isEmpty
        ? ''
        : output.continuumHintsClause(sem.hintSignals.join(', '));

    final eventLabel = output.eventClassLabel(classification.eventClass);
    final lean = output.leanLabel(core.lean);
    final regressive = core.lean == 'REGRESSIVE';

    final signals = output.strings
        .t('continuum_conclusion_signals')
        .replaceAll('{question}', question)
        .replaceAll('{frame}', output.partTwoFrameLabel(sem.frame))
        .replaceAll('{polarity}', output.partTwoPolarityLabel(sem.polarity))
        .replaceAll('{event_class}', eventLabel)
        .replaceAll('{horizon}', '${classification.horizonDays}')
        .replaceAll('{region}', regionLabel)
        .replaceAll('{hints_clause}', hints);

    final constructs = output.strings
        .t('continuum_conclusion_constructs')
        .replaceAll('{vortex_scs}', '$vortexScs')
        .replaceAll('{shear_scs}', '$shearScs')
        .replaceAll('{res_scs}', '$resistanceScs')
        .replaceAll('{flow_scs}', '$flowScs')
        .replaceAll('{w_v}', '${wPct[4]}')
        .replaceAll('{w_s}', '${wPct[2]}')
        .replaceAll('{w_r}', '${wPct[3]}')
        .replaceAll('{w_f}', '${wPct[1]}')
        .replaceAll('{refined}', '${core.refinedScs.round()}')
        .replaceAll('{reg}', '${core.regressivePct.round()}')
        .replaceAll('{prog}', '${core.progressivePct.round()}')
        .replaceAll('{lean}', lean);

    final registryFilter = output.strings
        .t('explainer_registry_filter')
        .replaceAll('{event_class}', eventLabel)
        .replaceAll('{region}', regionLabel)
        .replaceAll('{horizon}', '${classification.horizonDays}')
        .replaceAll('{n}', '${forecast.sampleSize}')
        .replaceAll('{successes}', '${forecast.successCount}');

    final registrySummary = output.strings
        .t('continuum_conclusion_registry')
        .replaceAll('{event_class}', eventLabel)
        .replaceAll('{base_rate}', forecast.baseRatePercent.toStringAsFixed(1))
        .replaceAll('{n}', '${forecast.sampleSize}')
        .replaceAll('{year_min}', '${forecast.yearMin}')
        .replaceAll('{year_max}', '${forecast.yearMax}')
        .replaceAll('{hist_ci_low}', '${forecast.baseCiLow.round()}')
        .replaceAll('{hist_ci_high}', '${forecast.baseCiHigh.round()}')
        .replaceAll('{brier}', forecast.brierScore.toStringAsFixed(2))
        .replaceAll('{sources}', forecast.provenance)
        .replaceAll('{horizon}', '${classification.horizonDays}');

    final calibrationSummary = output.strings
        .t('continuum_conclusion_calibration')
        .replaceAll('{lean}', lean)
        .replaceAll('{outcome_qualifier}', output.continuumOutcomeQualifier(regressive))
        .replaceAll('{pct}', '${forecast.calibratedPercent.round()}')
        .replaceAll('{ci_low}', '${forecast.ciLow}')
        .replaceAll('{ci_high}', '${forecast.ciHigh}')
        .replaceAll('{base_w}', '${(baseWeight * 100).round()}')
        .replaceAll('{base_rate}', forecast.baseRatePercent.toStringAsFixed(1))
        .replaceAll('{heur_w}', '${(heuristicWeight * 100).round()}')
        .replaceAll('{heuristic_pct}', forecast.heuristicPercent.toStringAsFixed(1));

    return ConclusionExplainerData(
      construalSignals: signals,
      construalConstructs: constructs,
      registryFilter: registryFilter,
      registrySummary: registrySummary,
      calibrationSummary: calibrationSummary,
      matchedCaseLines: forecast.matchedCaseLines,
      successCount: forecast.successCount,
      sampleSize: forecast.sampleSize,
    );
  }
}