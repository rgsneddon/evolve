import '../l10n/localized_output.dart';
import '../models/forecast_result.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'chronoflux_weight_construal.dart';
import 'event_classifier.dart';
import 'question_semantics.dart';
import 'question_relevance_filter.dart';
import 'scenario_calculation_context.dart';

/// CONCLUSION — THE CONTINUUM: question-specific data points used to construe.
class ContinuumConclusionBuilder {
  const ContinuumConclusionBuilder({
    this.weightConstrual = const ChronofluxWeightConstrual(),
    this.classifier = const EventClassifier(),
    this.baseWeight = 0.6,
    this.heuristicWeight = 0.4,
  });

  final ChronofluxWeightConstrual weightConstrual;
  final EventClassifier classifier;
  final double baseWeight;
  final double heuristicWeight;

  String build({
    required ScenarioInput input,
    required LocaleConfig locale,
    required LocalizedOutput output,
    required ForecastResult forecast,
    required HydrodynamicCore core,
    required String percentPhrase,
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

    final questionHints = QuestionRelevanceFilter.questionDerivedHints(sem.hintSignals);
    final hints = questionHints.isEmpty
        ? ''
        : output.continuumHintsClause(questionHints.join(', '));

    return output.continuumConclusion(
      percentPhrase: percentPhrase,
      question: question,
      frame: sem.frame,
      polarity: sem.polarity,
      eventClass: output.eventClassLabel(classification.eventClass),
      horizonDays: classification.horizonDays,
      region: regionLabel,
      hintsClause: hints,
      vortexScs: vortexScs,
      shearScs: shearScs,
      resistanceScs: resistanceScs,
      flowScs: flowScs,
      weightVortexPct: wPct[4],
      weightShearPct: wPct[2],
      weightResistancePct: wPct[3],
      weightFlowPct: wPct[1],
      refinedScs: core.refinedScs.round(),
      regressivePct: core.regressivePct.round(),
      progressivePct: core.progressivePct.round(),
      lean: output.leanLabel(core.lean),
      baseRatePct: forecast.baseRatePercent.toStringAsFixed(1),
      sampleSize: forecast.sampleSize,
      yearMin: forecast.yearMin,
      yearMax: forecast.yearMax,
      histCiLow: forecast.baseCiLow.round(),
      histCiHigh: forecast.baseCiHigh.round(),
      brier: forecast.brierScore.toStringAsFixed(2),
      provenance: forecast.provenance,
      calibratedPct: forecast.calibratedPercent.round(),
      ciLow: forecast.ciLow,
      ciHigh: forecast.ciHigh,
      heuristicPct: forecast.heuristicPercent.toStringAsFixed(1),
      baseWeightPct: (baseWeight * 100).round(),
      heuristicWeightPct: (heuristicWeight * 100).round(),
      regressive: core.lean == 'REGRESSIVE',
      successCount: forecast.successCount,
      matchedCaseLines: forecast.matchedCaseLines,
    );
  }
}