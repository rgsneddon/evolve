import '../l10n/localized_output.dart';
import '../models/forecast_result.dart';
import '../models/locale_config.dart';
import '../models/party_response_scs.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'cohesion_narrative_formatter.dart';

/// Full cohesion report — MarkdownBin-style SSUCF layout in the user's language.
class CohesionReportFormatter {
  const CohesionReportFormatter({
    this.narratives = const CohesionNarrativeFormatter(),
  });

  final CohesionNarrativeFormatter narratives;

  String format({
    required ScenarioInput input,
    required HydrodynamicCore core,
    required PartOneSection partOne,
    required PartTwoSection partTwo,
    required PartThreeSection partThree,
    required Map<String, String> fieldNarratives,
    required ForecastResult forecast,
    required LocalizedOutput output,
    required LocaleConfig locale,
    NarrativePartyRefinement? partyRefinement,
  }) {
    final s = output.strings;
    final title = input.topic.trim().isNotEmpty
        ? input.topic.trim()
        : (input.posedQuestionLine ?? input.scenarioQuery);

    final buf = StringBuffer()
      ..writeln(s.t('cohesion_title').replaceAll('{title}', title))
      ..writeln()
      ..writeln(s.t('cohesion_subtitle'))
      ..writeln(s.t('cohesion_topic').replaceAll(
          '{topic}', input.posedQuestionLine ?? input.scenarioQuery))
      ..writeln()
      ..writeln(s.t('cohesion_part_one'))
      ..writeln()
      ..writeln(s.t('cohesion_vortex'))
      ..write(_bullets(narratives.partOneVortex(
        input: input,
        narrative: fieldNarratives['vortex']!,
        scs: core.vortexScs.round(),
        out: output,
        locale: locale,
      )))
      ..writeln()
      ..writeln(s.t('cohesion_shear'))
      ..write(_bullets(narratives.partOneShear(
        input: input,
        narrative: fieldNarratives['shear']!,
        out: output,
        locale: locale,
      )))
      ..writeln()
      ..writeln(s.t('cohesion_resistance'))
      ..write(_bullets(narratives.partOneResistance(
        input: input,
        narrative: fieldNarratives['resistance']!,
      )))
      ..writeln()
      ..writeln(s.t('cohesion_flow'))
      ..write(_bullets(narratives.partOneFlow(
        input: input,
        narrative: fieldNarratives['flow']!,
      )))
      ..writeln()
      ..writeln(s.t('cohesion_baseline')
          .replaceAll('{scs}', '${partOne.baselineScs.round()}'))
      ..writeln(s.t('cohesion_weighted')
          .replaceAll('{scs}', partOne.overallScs.toStringAsFixed(1)))
      ..writeln(s.t('cohesion_split')
          .replaceAll('{reg}', '${partOne.regressivePct.round()}')
          .replaceAll('{prog}', '${partOne.progressivePct.round()}'))
      ..writeln()
      ..writeln(s.t('cohesion_part_two'))
      ..writeln()
      ..writeln(s.t('cohesion_expanded_vortex'))
      ..write(_bullets(narratives.partTwoExpanded(
        input: input,
        partTwo: partTwo,
        out: output,
        locale: locale,
      )))
      ..writeln()
      ..writeln(s.t('cohesion_shear_refine'))
      ..write(_bullets(narratives.partTwoShear(
        input: input,
        partTwo: partTwo,
        out: output,
        locale: locale,
      )))
      ..writeln()
      ..writeln(s.t('cohesion_resistance_flow'))
      ..write(_bullets(narratives.partTwoResistanceFlow(
        partTwo: partTwo,
        out: output,
      )))
      ..writeln()
      ..writeln(s.t('cohesion_refined')
          .replaceAll('{scs}', '${partTwo.refinedScs.round()}'))
      ..writeln(s.t('cohesion_split')
          .replaceAll('{reg}', '${partTwo.regressivePct.round()}')
          .replaceAll('{prog}', '${partTwo.progressivePct.round()}'));

    if (partyRefinement != null && partyRefinement.applied) {
      buf
        ..writeln()
        ..writeln(s.t('party_response_section'))
        ..writeln()
        ..writeln(partyRefinement.summary)
        ..writeln();
      for (final response in partyRefinement.responses) {
        buf
          ..writeln(
            s.t('party_response_line').replaceAll('{party}', response.party),
          )
          ..writeln(
            s
                .t('party_response_scs')
                .replaceAll('{scs}', '${response.scs.round()}')
                .replaceAll('{reg}', '${response.regressivePct.round()}')
                .replaceAll('{prog}', '${response.progressivePct.round()}')
                .replaceAll('{lean}', output.leanLabel(response.lean)),
          )
          ..writeln('* "${response.excerpt}"')
          ..writeln();
      }
      buf.writeln(
        s
            .t('party_response_refined')
            .replaceAll('{before}', '${partyRefinement.narrativeScsBefore.round()}')
            .replaceAll('{after}', '${partyRefinement.refinedNarrativeScs.round()}'),
      );
    }

    buf
      ..writeln()
      ..writeln(s.t('cohesion_part_three'))
      ..writeln()
      ..writeln(s.t('cohesion_interventions'));

    for (var i = 0; i < partThree.interventions.length; i++) {
      buf.writeln('${i + 1}. ${partThree.interventions[i]}');
    }

    buf
      ..writeln()
      ..writeln(s.t('cohesion_outcomes'))
      ..writeln(s.t('cohesion_without')
          .replaceAll('{scs}', '${partThree.withoutLeversScs.round()}'))
      ..writeln(s.t('cohesion_with')
          .replaceAll('{min}', '${partThree.withLeversMin.round()}')
          .replaceAll('{max}', '${partThree.withLeversMax.round()}'))
      ..writeln()
      ..writeln(s.t('cohesion_conclusion_heading'))
      ..writeln()
      ..writeln(narratives.finalSummary(
        input: input,
        out: output,
        locale: locale,
        overallScs: partOne.overallScs,
      ))
      ..writeln()
      ..writeln(output.cohesionCycleComplete);

    return buf.toString();
  }

  String _bullets(List<String> items) {
    if (items.isEmpty) return '';
    return items.map((item) => '* $item').join('\n');
  }
}