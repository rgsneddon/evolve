import '../l10n/app_localizations.dart';
import '../models/scenario_input.dart';
import 'part_three_action_builder.dart';
import 'question_semantics.dart';
import 'scenario_input_profile.dart';
import 'scenario_lean_context.dart';

/// Discourse themes — construal of social discourse in a given scenario.
enum DiscourseTheme {
  protest,
  official,
  economic,
  electoral,
  trust,
  accountability,
  open;

  String get key => switch (this) {
        DiscourseTheme.protest => 'protest',
        DiscourseTheme.official => 'official',
        DiscourseTheme.economic => 'economic',
        DiscourseTheme.electoral => 'electoral',
        DiscourseTheme.trust => 'trust',
        DiscourseTheme.accountability => 'accountability',
        DiscourseTheme.open => 'open',
      };
}

/// Scenario-specific recommendations from ω/σ/Iτ/Jμ discourse construal.
class SocialDiscourseConstrual {
  const SocialDiscourseConstrual();

  DiscourseTheme detect(ScenarioInput input, QuestionSemantics sem) {
    final text = _corpus(input);

    if (_has(text, r'\b(protest|unrest|riot|disorder|march|rally|demonstration)\b')) {
      return DiscourseTheme.protest;
    }
    if (_has(text, r'\b(strike|transit|inflation|economy|recession|cost of living|union|labou?r)\b')) {
      return DiscourseTheme.economic;
    }
    if (_has(text, r'\b(election|vote|referendum|ballot|campaign)\b')) {
      return DiscourseTheme.electoral;
    }
    if (_has(text, r'\b(resign|scandal|accountability|impeach|misconduct)\b')) {
      return DiscourseTheme.accountability;
    }
    if (_has(text,
        r'\b(trust|narrative|lens|believe|condemn|condemnation|selective|sceptic|skeptic)\b')) {
      return DiscourseTheme.trust;
    }
    if (_has(text,
        r'\b(minister|mayor|statement|briefing|official|government|first minister|premier)\b')) {
      return DiscourseTheme.official;
    }

    if (sem.hintSignals.contains('collective-disorder circulation')) {
      return DiscourseTheme.protest;
    }
    if (sem.hintSignals.contains('electoral vortex')) return DiscourseTheme.electoral;
    if (sem.hintSignals.contains('macro-economic pressure')) return DiscourseTheme.economic;
    if (sem.hintSignals.contains('narrative-lens compression')) return DiscourseTheme.trust;
    if (sem.hintSignals.contains('institutional framing')) return DiscourseTheme.official;

    return DiscourseTheme.open;
  }

  /// Three concise actions — improve SCS / shift PROGRESSIVE.
  List<String> slimPartThreeActions({
    required DiscourseTheme theme,
    required String agent,
    required ScenarioInputProfile profile,
    required AppLocalizations strings,
  }) =>
      List.generate(
        3,
        (i) => _substitute(
          strings.t('discourse_${theme.key}_slim_${i + 1}'),
          agent,
          profile,
        ),
      );

  /// Five concise cohesion interventions — progressive transport levers.
  List<String> slimInterventions({
    required ScenarioInputProfile profile,
    required AppLocalizations strings,
  }) =>
      List.generate(
        PartThreeActionBuilder.actionCount,
        (i) => strings
            .t('part3_slim_intervention_${i + 1}')
            .replaceAll('{subject}', profile.subject),
      );

  List<String> partThreeActions({
    required DiscourseTheme theme,
    required String agent,
    required ScenarioInputProfile profile,
    required AppLocalizations strings,
    required ScenarioLeanContext leanCtx,
  }) =>
      List.generate(
        3,
        (i) => _fillAction(
          _actionTemplate(strings, theme, i + 1, leanCtx),
          agent,
          profile,
          leanCtx,
          strings,
        ),
      );

  List<String> interventions({
    required DiscourseTheme theme,
    required ScenarioInputProfile profile,
    required AppLocalizations strings,
    required ScenarioLeanContext leanCtx,
  }) =>
      List.generate(
        4,
        (i) => _fillIntervention(
          _interventionTemplate(strings, theme, i + 1, leanCtx),
          profile,
          leanCtx,
          strings,
        ),
      );

  String discourseContextLine({
    required DiscourseTheme theme,
    required AppLocalizations strings,
    required ScenarioInputProfile profile,
    required ScenarioLeanContext leanCtx,
  }) {
    final base = strings
        .t('discourse_${theme.key}_context')
        .replaceAll('{subject}', profile.subject)
        .replaceAll('{topic_suffix}', profile.topicSuffix);
    return '$base ${leanCtx.understandingLine(strings)}';
  }

  static String _actionTemplate(
    AppLocalizations strings,
    DiscourseTheme theme,
    int index,
    ScenarioLeanContext leanCtx,
  ) {
    if (leanCtx.mitigateScenario) {
      return _resolve(strings, 'discourse_${theme.key}_mitigate_action_$index',
          'discourse_${theme.key}_action_$index');
    }
    if (leanCtx.supportScenario) {
      return _resolve(
        strings,
        'discourse_${theme.key}_support_action_$index',
        'discourse_open_support_action_$index',
        'discourse_${theme.key}_action_$index',
      );
    }
    return strings.t('discourse_${theme.key}_action_$index');
  }

  static String _interventionTemplate(
    AppLocalizations strings,
    DiscourseTheme theme,
    int index,
    ScenarioLeanContext leanCtx,
  ) {
    if (leanCtx.mitigateScenario) {
      return _resolve(strings, 'discourse_${theme.key}_mitigate_intervention_$index',
          'discourse_${theme.key}_intervention_$index');
    }
    if (leanCtx.supportScenario) {
      return _resolve(
        strings,
        'discourse_${theme.key}_support_intervention_$index',
        'discourse_open_support_intervention_$index',
        'discourse_${theme.key}_intervention_$index',
      );
    }
    return strings.t('discourse_${theme.key}_intervention_$index');
  }

  static String _resolve(AppLocalizations strings, String primary, String fallback,
      [String? fallback2]) {
    final p = strings.t(primary);
    if (p != primary) return p;
    final f = strings.t(fallback);
    if (f != fallback) return f;
    if (fallback2 != null) return strings.t(fallback2);
    return f;
  }

  static String _corpus(ScenarioInput input) =>
      '${input.posedQuestion} ${input.topic} ${input.vortexText} ${input.shearText} '
              '${input.resistanceText} ${input.flowText}'
          .toLowerCase();

  static bool _has(String text, String pattern) => RegExp(pattern).hasMatch(text);

  static String _fillAction(
    String template,
    String agent,
    ScenarioInputProfile profile,
    ScenarioLeanContext leanCtx,
    AppLocalizations strings,
  ) {
    var result = _substitute(template, agent, profile);
    if (leanCtx.mitigateScenario) {
      result =
          '$result ${strings.t('lean_aim_mitigate').replaceAll('{subject}', profile.subject)}';
    } else if (leanCtx.supportScenario) {
      result =
          '$result ${strings.t('lean_aim_support').replaceAll('{subject}', profile.subject)}';
    }
    return result;
  }

  static String _fillIntervention(
    String template,
    ScenarioInputProfile profile,
    ScenarioLeanContext leanCtx,
    AppLocalizations strings,
  ) {
    var result = template
        .replaceAll('{subject}', profile.subject)
        .replaceAll('{topic_suffix}', profile.topicSuffix)
        .replaceAll('{vortex_snip}', _snip(profile.vortexRaw))
        .replaceAll('{shear_snip}', _snip(profile.shearRaw))
        .replaceAll('{resistance_snip}', _snip(profile.resistanceRaw))
        .replaceAll('{flow_snip}', _snip(profile.flowRaw));
    if (leanCtx.mitigateScenario) {
      result = '$result ${strings.t('lean_aim_mitigate_short')}';
    } else if (leanCtx.supportScenario) {
      result = '$result ${strings.t('lean_aim_support_short')}';
    }
    return result;
  }

  static String substitute(String template, String agent, ScenarioInputProfile profile) =>
      _substitute(template, agent, profile);

  static String _substitute(String template, String agent, ScenarioInputProfile profile) =>
      template
          .replaceAll('{agent}', agent)
          .replaceAll('{subject}', profile.subject)
          .replaceAll('{topic_suffix}', profile.topicSuffix)
          .replaceAll('{shear_hook}', profile.shearHook)
          .replaceAll('{resistance_hook}', profile.resistanceHook)
          .replaceAll('{flow_hook}', profile.flowHook)
          .replaceAll('{vortex_snip}', _snip(profile.vortexRaw))
          .replaceAll('{shear_snip}', _snip(profile.shearRaw))
          .replaceAll('{resistance_snip}', _snip(profile.resistanceRaw))
          .replaceAll('{flow_snip}', _snip(profile.flowRaw));

  static String _snip(String text, [int max = 72]) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return '';
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }
}