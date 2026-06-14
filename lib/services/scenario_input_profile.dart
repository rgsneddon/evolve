import '../l10n/app_localizations.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'question_semantics.dart';
import 'region_context.dart';
import 'scenario_lean_context.dart';

/// Full input binding — ties PART THREE actions to every ω/σ/Iτ/Jμ field.
class ScenarioInputProfile {
  const ScenarioInputProfile({
    required this.subject,
    required this.topic,
    required this.vortexRaw,
    required this.shearRaw,
    required this.resistanceRaw,
    required this.flowRaw,
    required this.bindingSummary,
    required this.topicSuffix,
    required this.shearHook,
    required this.resistanceHook,
    required this.flowHook,
  });

  final String subject;
  final String topic;
  final String vortexRaw;
  final String shearRaw;
  final String resistanceRaw;
  final String flowRaw;
  final String bindingSummary;
  final String topicSuffix;
  final String shearHook;
  final String resistanceHook;
  final String flowHook;

  factory ScenarioInputProfile.from({
    required ScenarioInput input,
    required HydrodynamicCore core,
    LocaleConfig locale = LocaleConfig.defaults,
  }) {
    final strings = AppLocalizations.of(locale);
    final regionLabel = strings.t('region_${locale.regionId}');
    final region = RegionContext(locale.regionId);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: regionLabel,
    );
    final topic = input.topic.trim();
    final vortex = region.scopeFieldText(input.vortexText.trim(), regionLabel);
    final shear = region.scopeFieldText(input.shearText.trim(), regionLabel);
    final resistance =
        region.scopeFieldText(input.resistanceText.trim(), regionLabel);
    final flow = region.scopeFieldText(input.flowText.trim(), regionLabel);

    final topicSuffix = topic.isNotEmpty
        ? strings.t('part3_topic_suffix').replaceAll('{topic}', topic)
        : '';

    final shearHook = shear.isNotEmpty
        ? strings.t('part3_shear_user').replaceAll('{text}', _snip(shear))
        : strings
            .t('part3_shear_observed')
            .replaceAll('{scs}', '${core.shearScs.round()}');

    final resistanceHook = resistance.isNotEmpty
        ? strings.t('part3_resistance_user').replaceAll('{text}', _snip(resistance))
        : strings
            .t('part3_resistance_observed')
            .replaceAll('{scs}', '${core.resistanceScs.round()}');

    final flowHook = flow.isNotEmpty
        ? strings.t('part3_flow_user').replaceAll('{text}', _snip(flow))
        : strings.t('part3_flow_observed').replaceAll('{scs}', '${core.flowScs.round()}');

    final leanCtx = ScenarioLeanContext.from(core: core, sem: sem);
    final parts = <String>[
      leanCtx.bindingLeanTag(strings),
      strings
          .t('bind_region')
          .replaceAll('{region}', strings.t('region_${locale.regionId}')),
      if (topic.isNotEmpty) strings.t('bind_topic').replaceAll('{topic}', topic),
      strings
          .t('bind_posed_question')
          .replaceAll('{value}', sem.displaySubject),
      if (vortex.isNotEmpty)
        strings.t('bind_vortex_variable').replaceAll('{value}', _snip(vortex)),
      shear.isNotEmpty
          ? strings.t('bind_shear').replaceAll('{value}', _snip(shear))
          : strings
              .t('bind_shear_observed')
              .replaceAll('{scs}', '${core.shearScs.round()}'),
      resistance.isNotEmpty
          ? strings.t('bind_resistance').replaceAll('{value}', _snip(resistance))
          : strings
              .t('bind_resistance_observed')
              .replaceAll('{scs}', '${core.resistanceScs.round()}'),
      flow.isNotEmpty
          ? strings.t('bind_flow').replaceAll('{value}', _snip(flow))
          : strings.t('bind_flow_observed').replaceAll('{scs}', '${core.flowScs.round()}'),
    ];

    return ScenarioInputProfile(
      subject: sem.displaySubject,
      topic: topic,
      vortexRaw: vortex,
      shearRaw: shear,
      resistanceRaw: resistance,
      flowRaw: flow,
      bindingSummary: parts.join(' · '),
      topicSuffix: topicSuffix,
      shearHook: shearHook,
      resistanceHook: resistanceHook,
      flowHook: flowHook,
    );
  }

  static String _snip(String text, [int max = 72]) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }
}