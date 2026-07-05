import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'question_semantics.dart';

/// MarkdownBin-style concise bullets for cohesion reports.
class CohesionNarrativeFormatter {
  const CohesionNarrativeFormatter();

  List<String> partOneVortex({
    required ScenarioInput input,
    required String narrative,
    required int scs,
    required LocalizedOutput out,
    required LocaleConfig locale,
  }) {
    final text = input.vortexText.trim();
    if (text.isNotEmpty) {
      final bullets = <String>[
        out.strings
            .t('cohesion_bullet_core_input')
            .replaceAll('{text}', text),
        out.strings
            .t('cohesion_vortex_signal')
            .replaceAll('{scs}', '$scs'),
      ];
      return bullets;
    }
    return [_conciseObs(narrative)];
  }

  List<String> partOneShear({
    required ScenarioInput input,
    required String narrative,
    required LocalizedOutput out,
    required LocaleConfig locale,
  }) {
    final text = input.shearText.trim();
    if (text.isNotEmpty) {
      return [
        out.strings
            .t('cohesion_bullet_social_force')
            .replaceAll('{text}', text),
      ];
    }
    return [_conciseObs(narrative)];
  }

  List<String> partOneResistance({
    required ScenarioInput input,
    required String narrative,
  }) {
    final text = input.resistanceText.trim();
    if (text.isNotEmpty) return [text];
    return [_conciseObs(narrative)];
  }

  List<String> partOneFlow({
    required ScenarioInput input,
    required String narrative,
  }) {
    final text = input.flowText.trim();
    if (text.isNotEmpty) return [text];
    return [_conciseObs(narrative)];
  }

  List<String> partTwoExpanded({
    required ScenarioInput input,
    required PartTwoSection partTwo,
    required LocalizedOutput out,
    required LocaleConfig locale,
  }) {
    final s = out.strings;
    return [
      partTwo.expandedVortex,
      s
          .t('cohesion_p2_continuum_lean')
          .replaceAll('{reg}', '${partTwo.regressivePct.round()}')
          .replaceAll('{prog}', '${partTwo.progressivePct.round()}'),
    ];
  }

  List<String> partTwoShear({
    required ScenarioInput input,
    required PartTwoSection partTwo,
    required LocalizedOutput out,
    required LocaleConfig locale,
  }) {
    return [partTwo.shearRefinement];
  }

  List<String> partTwoResistanceFlow({
    required PartTwoSection partTwo,
    required LocalizedOutput out,
  }) {
    return [partTwo.resistanceFlow];
  }

  String finalSummary({
    required ScenarioInput input,
    required LocalizedOutput out,
    required LocaleConfig locale,
    required double overallScs,
  }) {
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );
    final subject = sem.displaySubject;
    final weighted = out.cohesionWeightedLine(overallScs);
    final summary = out.strings
        .t('cohesion_final_dynamic')
        .replaceAll('{subject}', subject);
    return '$weighted\n\n$summary';
  }

  String _conciseObs(String narrative) {
    final t = narrative.trim();
    final colon = t.indexOf(':');
    if (colon > 0 && t.length > colon + 2) {
      return t.substring(colon + 1).trim();
    }
    return t;
  }
}