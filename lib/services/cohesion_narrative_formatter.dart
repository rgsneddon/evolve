import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'question_semantics.dart';
import 'social_discourse_construal.dart';

/// MarkdownBin-style concise bullets for cohesion reports.
class CohesionNarrativeFormatter {
  const CohesionNarrativeFormatter({
    this.discourse = const SocialDiscourseConstrual(),
  });

  final SocialDiscourseConstrual discourse;

  List<String> partOneVortex({
    required ScenarioInput input,
    required String narrative,
    required int scs,
    required LocalizedOutput out,
    required LocaleConfig locale,
  }) {
    final text = input.vortexText.trim();
    if (text.isNotEmpty) {
      final sem = QuestionSemantics.parse(
        input,
        regionId: locale.regionId,
        regionLabel: out.regionName(locale.regionId),
      );
      final bullets = <String>[
        out.strings
            .t('cohesion_bullet_core_input')
            .replaceAll('{text}', text),
      ];
      final mismatch = _vortexMismatch(sem, scs, out);
      if (mismatch != null) bullets.add(mismatch);
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
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );
    final theme = discourse.detect(input, sem);
    final subject = sem.displaySubject;
    final topic = input.topic.trim();
    final s = out.strings;

    if (theme == DiscourseTheme.protest || theme == DiscourseTheme.official) {
      return [
        if (topic.isNotEmpty)
          s.t('cohesion_p2_vortex_elite_topic')
              .replaceAll('{topic}', topic)
              .replaceAll('{subject}', subject),
        s.t('cohesion_p2_vortex_elite_framing')
            .replaceAll('{subject}', subject)
            .replaceAll('{scs}', '${partTwo.core.vortexScs.round()}'),
      ];
    }

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
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );
    final theme = discourse.detect(input, sem);
    final subject = sem.displaySubject;
    final s = out.strings;

    if (theme == DiscourseTheme.protest || theme == DiscourseTheme.trust) {
      return [
        s.t('cohesion_p2_shear_elite_vs_public')
            .replaceAll('{subject}', subject),
        s.t('cohesion_p2_shear_asymmetric')
            .replaceAll('{scs}', '${partTwo.core.shearScs.round()}'),
      ];
    }

    return [partTwo.shearRefinement];
  }

  List<String> partTwoResistanceFlow({
    required PartTwoSection partTwo,
    required LocalizedOutput out,
  }) {
    final lean = out.leanLabel(partTwo.lean);
    if (partTwo.core.resistanceScs >= partTwo.core.flowScs + 6) {
      return [
        out.strings
            .t('cohesion_p2_rf_short_term_calm')
            .replaceAll('{lean}', lean),
      ];
    }
    if (partTwo.core.flowScs >= partTwo.core.resistanceScs + 6) {
      return [
        out.strings
            .t('cohesion_p2_rf_trust_transport')
            .replaceAll('{lean}', lean),
      ];
    }
    return [partTwo.resistanceFlow];
  }

  String finalSummary({
    required ScenarioInput input,
    required LocalizedOutput out,
    required LocaleConfig locale,
  }) {
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );
    final subject = sem.displaySubject;
    return out.strings
        .t('cohesion_final_dynamic')
        .replaceAll('{subject}', subject);
  }

  String? _vortexMismatch(QuestionSemantics sem, int scs, LocalizedOutput out) {
    final hints = sem.hintSignals.map((h) => h.toLowerCase()).toList();
    if (hints.any((h) =>
        h.contains('narrative') ||
        h.contains('disorder') ||
        h.contains('institutional'))) {
      return out.strings
          .t('cohesion_vortex_mismatch_narrative')
          .replaceAll('{scs}', '$scs');
    }
    return out.strings
        .t('cohesion_vortex_signal')
        .replaceAll('{scs}', '$scs');
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