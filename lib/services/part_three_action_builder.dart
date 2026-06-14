import '../l10n/app_localizations.dart';
import '../models/forecast_result.dart';
import '../models/part_three_conclusion.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'chronoflux_weight_construal.dart';
import 'question_semantics.dart';
import 'scenario_calculation_context.dart';
import 'scenario_input_profile.dart';
import 'scenario_lean_context.dart';
import 'social_discourse_construal.dart';

/// Builds five establishment-facing actions grounded in Chronoflux calculations.
class PartThreeActionBuilder {
  const PartThreeActionBuilder({
    this.construal = const SocialDiscourseConstrual(),
    this.weightConstrual = const ChronofluxWeightConstrual(),
  });

  static const actionCount = 5;

  final SocialDiscourseConstrual construal;
  final ChronofluxWeightConstrual weightConstrual;

  List<PartThreeAction> build({
    required ScenarioInput input,
    required HydrodynamicCore core,
    required PartThreeSection partThree,
    required ForecastResult forecast,
    required ScenarioInputProfile profile,
    required ScenarioLeanContext leanCtx,
    required QuestionSemantics sem,
    required String agent,
    required AppLocalizations strings,
    required String regionId,
  }) {
    final theme = construal.detect(input, sem);
    final weights = weightConstrual
        .construeFromContext(
          ScenarioCalculationContext.from(input: input, regionId: regionId),
        )
        .normalized;
    final friction = _frictionPriorities(core);

    final actions = <PartThreeAction>[
      _themeAction(
        index: 1,
        theme: theme,
        agent: agent,
        profile: profile,
        construct: 'ω',
        strings: strings,
        rationaleKey: 'part3_rationale_theme',
        rationaleArgs: {
          'theme': strings.t('discourse_${theme.key}_context')
              .replaceAll('{subject}', profile.subject)
              .replaceAll('{topic_suffix}', profile.topicSuffix),
        },
      ),
      _themeAction(
        index: 2,
        theme: theme,
        agent: agent,
        profile: profile,
        construct: 'σ',
        strings: strings,
        rationaleKey: 'part3_rationale_theme',
        rationaleArgs: {
          'theme': strings.t('discourse_${theme.key}_context')
              .replaceAll('{subject}', profile.subject)
              .replaceAll('{topic_suffix}', profile.topicSuffix),
        },
      ),
      _themeAction(
        index: 3,
        theme: theme,
        agent: agent,
        profile: profile,
        construct: 'Iτ/Jμ',
        strings: strings,
        rationaleKey: 'part3_rationale_theme',
        rationaleArgs: {
          'theme': strings.t('discourse_${theme.key}_context')
              .replaceAll('{subject}', profile.subject)
              .replaceAll('{topic_suffix}', profile.topicSuffix),
        },
      ),
      _constructAction(
        lever: friction.first,
        agent: agent,
        profile: profile,
        core: core,
        weightPct: _weightPct(weights, friction.first),
        strings: strings,
        leanCtx: leanCtx,
        vortexScs: core.vortexScs.round(),
      ),
      _capstoneAction(
        agent: agent,
        profile: profile,
        core: core,
        partThree: partThree,
        forecast: forecast,
        leanCtx: leanCtx,
        strings: strings,
      ),
    ];

    return actions;
  }

  PartThreeAction _themeAction({
    required int index,
    required DiscourseTheme theme,
    required String agent,
    required ScenarioInputProfile profile,
    required String construct,
    required AppLocalizations strings,
    required String rationaleKey,
    required Map<String, String> rationaleArgs,
  }) {
    final template = strings.t('discourse_${theme.key}_slim_$index');
    final action = SocialDiscourseConstrual.substitute(template, agent, profile);
    final rationale = strings
        .t(rationaleKey)
        .replaceAll('{theme}', rationaleArgs['theme'] ?? '')
        .replaceAll('{construct}', construct);
    return PartThreeAction(action: action, construct: construct, rationale: rationale);
  }

  PartThreeAction _constructAction({
    required _ConstructLever lever,
    required String agent,
    required ScenarioInputProfile profile,
    required HydrodynamicCore core,
    required int weightPct,
    required AppLocalizations strings,
    required ScenarioLeanContext leanCtx,
    required int vortexScs,
  }) {
    final scs = _scsFor(core, lever);
    final hook = _hookFor(profile, lever, strings, vortexScs: vortexScs);
    final key = switch (lever) {
      _ConstructLever.sigma => 'part3_construct_action_sigma',
      _ConstructLever.resistance => 'part3_construct_action_resistance',
      _ConstructLever.flow => 'part3_construct_action_flow',
      _ConstructLever.vortex => 'part3_construct_action_vortex',
    };
    final symbol = switch (lever) {
      _ConstructLever.sigma => 'σ',
      _ConstructLever.resistance => 'Iτ',
      _ConstructLever.flow => 'Jμ',
      _ConstructLever.vortex => 'ω',
    };

    final action = strings
        .t(key)
        .replaceAll('{agent}', agent)
        .replaceAll('{subject}', profile.subject)
        .replaceAll('{scs}', '$scs')
        .replaceAll('{weight}', '$weightPct')
        .replaceAll('{hook}', hook)
        .replaceAll('{reg}', '${leanCtx.regressivePct.round()}')
        .replaceAll('{prog}', '${leanCtx.progressivePct.round()}');

    final rationale = strings
        .t('part3_rationale_construct')
        .replaceAll('{construct}', symbol)
        .replaceAll('{scs}', '$scs')
        .replaceAll('{weight}', '$weightPct')
        .replaceAll('{reg}', '${leanCtx.regressivePct.round()}')
        .replaceAll('{prog}', '${leanCtx.progressivePct.round()}');

    return PartThreeAction(action: action, construct: symbol, rationale: rationale);
  }

  PartThreeAction _capstoneAction({
    required String agent,
    required ScenarioInputProfile profile,
    required HydrodynamicCore core,
    required PartThreeSection partThree,
    required ForecastResult forecast,
    required ScenarioLeanContext leanCtx,
    required AppLocalizations strings,
  }) {
    final action = strings
        .t('part3_progressive_capstone')
        .replaceAll('{agent}', agent)
        .replaceAll('{subject}', profile.subject)
        .replaceAll('{reg}', '${leanCtx.regressivePct.round()}')
        .replaceAll('{prog}', '${leanCtx.progressivePct.round()}')
        .replaceAll('{refined}', '${core.refinedScs.round()}')
        .replaceAll('{min}', '${partThree.withLeversMin.round()}')
        .replaceAll('{max}', '${partThree.withLeversMax.round()}')
        .replaceAll('{without}', '${partThree.withoutLeversScs.round()}')
        .replaceAll('{pct}', '${forecast.calibratedPercent.round()}')
        .replaceAll('{base}', forecast.baseRatePercent.toStringAsFixed(1))
        .replaceAll('{n}', '${forecast.sampleSize}')
        .replaceAll('{momentum}', core.netMomentum.toStringAsFixed(3));

    final rationale = strings
        .t('part3_rationale_capstone')
        .replaceAll('{reg}', '${leanCtx.regressivePct.round()}')
        .replaceAll('{prog}', '${leanCtx.progressivePct.round()}')
        .replaceAll('{refined}', '${core.refinedScs.round()}')
        .replaceAll('{pct}', '${forecast.calibratedPercent.round()}')
        .replaceAll('{n}', '${forecast.sampleSize}');

    return PartThreeAction(
      action: action,
      construct: 'ρt',
      rationale: rationale,
    );
  }

  static List<_ConstructLever> _frictionPriorities(HydrodynamicCore core) {
    final ranked = [
      (_ConstructLever.sigma, core.shearScs),
      (_ConstructLever.resistance, core.resistanceScs),
      (_ConstructLever.flow, 100 - core.flowScs),
      (_ConstructLever.vortex, 100 - core.vortexScs),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked.map((e) => e.$1).toList();
  }

  static int _scsFor(HydrodynamicCore core, _ConstructLever lever) => switch (lever) {
        _ConstructLever.sigma => core.shearScs.round(),
        _ConstructLever.resistance => core.resistanceScs.round(),
        _ConstructLever.flow => core.flowScs.round(),
        _ConstructLever.vortex => core.vortexScs.round(),
      };

  static int _weightPct(List<double> weights, _ConstructLever lever) {
    final idx = switch (lever) {
      _ConstructLever.sigma => 2,
      _ConstructLever.resistance => 3,
      _ConstructLever.flow => 1,
      _ConstructLever.vortex => 4,
    };
    return (weights[idx] * 100).round();
  }

  static String _hookFor(
    ScenarioInputProfile profile,
    _ConstructLever lever,
    AppLocalizations strings, {
    required int vortexScs,
  }) =>
      switch (lever) {
        _ConstructLever.sigma => profile.shearHook,
        _ConstructLever.resistance => profile.resistanceHook,
        _ConstructLever.flow => profile.flowHook,
        _ConstructLever.vortex => profile.vortexRaw.isNotEmpty
            ? strings
                .t('part3_vortex_hook')
                .replaceAll('{text}', _snip(profile.vortexRaw))
            : strings.t('part3_vortex_observed').replaceAll('{scs}', '$vortexScs'),
      };

  static String _snip(String text, [int max = 72]) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return stringsPlaceholder;
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static const stringsPlaceholder = '';
}

enum _ConstructLever { sigma, resistance, flow, vortex }