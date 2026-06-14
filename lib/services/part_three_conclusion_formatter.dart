import '../l10n/app_localizations.dart';
import '../models/analysis_mode.dart';
import '../models/forecast_result.dart';
import '../models/locale_config.dart';
import '../models/part_three_conclusion.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'part_three_action_builder.dart';
import 'question_semantics.dart';
import 'scenario_agent_detector.dart';
import 'scenario_input_profile.dart';
import 'scenario_lean_context.dart';

/// PART THREE — five data-driven actions to shift THE CONTINUUM PROGRESSIVE.
class PartThreeConclusionFormatter {
  const PartThreeConclusionFormatter({
    this.agentDetector = const ScenarioAgentDetector(),
    this.actionBuilder = const PartThreeActionBuilder(),
  });

  final ScenarioAgentDetector agentDetector;
  final PartThreeActionBuilder actionBuilder;

  PartThreeConclusion format({
    required AnalysisMode mode,
    required ScenarioInput input,
    required HydrodynamicCore core,
    required PartThreeSection partThree,
    required double percentChance,
    required ForecastResult forecast,
    required LocaleConfig locale,
  }) {
    final strings = AppLocalizations.of(locale);
    final profile = ScenarioInputProfile.from(
      input: input,
      core: core,
      locale: locale,
    );
    final agent = agentDetector.detect(
      scenarioText: input.scenarioQuery,
      topic: input.topic,
      locale: locale,
      strings: strings,
    );

    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: strings.t('region_${locale.regionId}'),
    );
    final leanCtx = ScenarioLeanContext.from(core: core, sem: sem);
    final actions = actionBuilder.build(
      input: input,
      core: core,
      partThree: partThree,
      forecast: forecast,
      profile: profile,
      leanCtx: leanCtx,
      sem: sem,
      agent: agent,
      strings: strings,
      regionId: locale.regionId,
    );

    final projected =
        leanCtx.progressiveShiftPercent(percentChance, actions.length);
    final isCohesion = mode == AnalysisMode.cohesionScore;

    final establishment = strings
        .t('part3_slim_establishment')
        .replaceAll('{agent}', agent)
        .replaceAll('{subject}', profile.subject);

    return PartThreeConclusion(
      headline: isCohesion
          ? strings.part3SlimHeadlineScs(agent)
          : strings.part3SlimHeadlinePct(agent),
      agentLabel: agent,
      contextLine: '$establishment\n${strings.part3SlimLeanLine(leanCtx, profile.subject, locale.regionId)}',
      inputBinding: profile.bindingSummary,
      actions: actions,
      targetLabel: isCohesion
          ? strings.part3SlimTargetScs(
              core.refinedScs.round(),
              partThree.withLeversMin.round(),
              partThree.withLeversMax.round(),
            )
          : strings.part3SlimTargetPct(
              percentChance.round(),
              projected,
              leanCtx,
            ),
      projectedImpact: isCohesion
          ? strings.part3SlimImpactScs(
              partThree.withLeversMin.round(),
              partThree.withLeversMax.round(),
            )
          : strings.part3SlimImpactPct(),
    );
  }
}