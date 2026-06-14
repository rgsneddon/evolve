import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/evolve_result.dart';

/// Plain-language explainers in the user's selected language.
class ConclusionExplainer {
  const ConclusionExplainer._();

  static ({String body, String conclusion}) splitGrokReply(
    String reply,
    LocaleConfig locale,
  ) {
    final marker = LocalizedOutput.of(locale).grokConclusionMarker;
    final idx = reply.indexOf(marker);
    if (idx < 0) return (body: reply, conclusion: '');
    return (
      body: reply.substring(0, idx).trim(),
      conclusion: reply.substring(idx).trim(),
    );
  }

  static ({String body, String conclusion}) splitCohesionReport(
    String report,
    LocaleConfig locale,
  ) {
    final out = LocalizedOutput.of(locale);
    final idx = report.indexOf(out.cohesionFinalSummary);
    if (idx < 0) return (body: report, conclusion: '');
    final endIdx = report.indexOf(out.cohesionCycleComplete, idx);
    if (endIdx < 0) {
      return (
        body: report.substring(0, idx).trim(),
        conclusion: report.substring(idx).trim(),
      );
    }
    final end = endIdx + out.cohesionCycleComplete.length;
    return (
      body: report.substring(0, idx).trim(),
      conclusion: report.substring(idx, end).trim(),
    );
  }

  static String percentChance(
    EvolveResult result, {
    required LocaleConfig locale,
    String? posedSubject,
  }) {
    final out = LocalizedOutput.of(locale);
    final core = result.core;
    final data = result.explainerData;
    final pct = result.percentChance.round();
    final subjectClause = posedSubject != null && posedSubject.isNotEmpty
        ? ' "${posedSubject}"'
        : '';
    final momentum = core.netMomentum >= 0
        ? '+${core.netMomentum.toStringAsFixed(3)}'
        : core.netMomentum.toStringAsFixed(3);

    final lead = out.strings
        .t('explainer_percent_lead')
        .replaceAll('{pct}', '$pct')
        .replaceAll('{subject_clause}', subjectClause)
        .replaceAll('{reg}', core.regressivePct.toStringAsFixed(1))
        .replaceAll('{shear}', '${core.shearScs.round()}')
        .replaceAll('{strain}', '${100 - core.refinedScs.round()}')
        .replaceAll('{momentum}', momentum)
        .replaceAll('{lean}', out.leanLabel(core.lean))
        .replaceAll(
          '{transport}',
          out.strings.t(
            core.lean == 'PROGRESSIVE'
                ? 'transport_progressive'
                : 'transport_regressive',
          ),
        );

    final sections = <String>[
      lead,
      out.strings.t('explainer_data_points_intro'),
      data.construalSignals,
      data.construalConstructs,
      data.registryFilter,
      data.registrySummary,
      data.calibrationSummary,
    ];

    if (data.sampleSize > 0) {
      sections.add(
        out.strings
            .t('explainer_registry_cases_intro')
            .replaceAll('{n}', '${data.sampleSize}')
            .replaceAll('{successes}', '${data.successCount}'),
      );
    } else {
      sections.add(out.strings.t('explainer_registry_cases_empty'));
    }

    return sections.join('\n\n');
  }

  static List<String> percentChanceBullets(
    EvolveResult result,
    LocaleConfig locale,
  ) {
    final out = LocalizedOutput.of(locale);
    final c = result.core;
    final s = out.strings;
    final data = result.explainerData;

    final bullets = <String>[
      s.t('bind_continuum_lean')
          .replaceAll('{lean}', out.leanLabel(c.lean))
          .replaceAll('{reg}', '${c.regressivePct.round()}')
          .replaceAll('{prog}', '${c.progressivePct.round()}'),
      out.constructBullet('ω', c.vortexScs.round(), s.t('label_vortex')),
      out.constructBullet('σ', c.shearScs.round(), s.t('label_shear')),
      out.constructBullet('Iτ', c.resistanceScs.round(), s.t('label_resistance')),
      out.constructBullet('Jμ', c.flowScs.round(), s.t('label_flow')),
      out.constructBullet('', c.refinedScs.round(), s.t('label_refined')),
      ...data.matchedCaseLines,
    ];

    return bullets;
  }

  static String cohesion(EvolveResult result, LocaleConfig locale) {
    final out = LocalizedOutput.of(locale);
    final core = result.core;
    final p3 = result.partThree;
    final data = result.explainerData;
    final baseline = core.baselineScs.round();
    final refined = core.refinedScs.round();
    final delta = refined - baseline;

    final body = out.explainerCohesion(
      refined: refined,
      baseline: baseline,
      deltaWord: out.cohesionDeltaWord(delta),
      prog: core.progressivePct.round(),
      reg: core.regressivePct.round(),
      progressive: core.lean == 'PROGRESSIVE',
      withMin: p3.withLeversMin.round(),
      withMax: p3.withLeversMax.round(),
      without: p3.withoutLeversScs.round(),
      recurrence: p3.recurrenceRisk,
    );

    final sections = <String>[
      body,
      out.strings.t('explainer_data_points_intro'),
      data.construalSignals,
      data.construalConstructs,
      data.registryFilter,
      data.registrySummary,
      data.calibrationSummary,
    ];

    if (data.sampleSize > 0) {
      sections.add(
        out.strings
            .t('explainer_registry_cases_intro')
            .replaceAll('{n}', '${data.sampleSize}')
            .replaceAll('{successes}', '${data.successCount}'),
      );
    }

    return sections.join('\n\n');
  }

  static List<String> cohesionBullets(EvolveResult result, LocaleConfig locale) {
    final out = LocalizedOutput.of(locale);
    final s = out.strings;
    final c = result.core;
    final data = result.explainerData;
    final delta = (c.refinedScs - c.baselineScs).round();
    return [
      '${s.t('label_strongest')}: ${_localizedConstruct(_strongest(c), s)}',
      '${s.t('label_weakest')}: ${_localizedConstruct(_weakest(c), s)}',
      s.t('label_baseline_delta_fmt')
          .replaceAll('{from}', '${c.baselineScs.round()}')
          .replaceAll('{to}', '${c.refinedScs.round()}')
          .replaceAll('{delta}', '$delta'),
      s.t('label_levers_count')
          .replaceAll('{n}', '${result.partThree.interventions.length}')
          .replaceAll('{label}', s.t('label_levers')),
      ...data.matchedCaseLines,
    ];
  }

  static String _localizedConstruct(
    MapEntry<String, double> entry,
    dynamic strings,
  ) =>
      '${strings.t(_constructNameKey(entry.key))} (${entry.value.round()}/100)';

  static String _constructNameKey(String symbol) => switch (symbol) {
        'ρt' => 'construct_continuum_name',
        'ω' => 'construct_vortex_name',
        'σ' => 'construct_shear_name',
        'Iτ' => 'construct_resistance_name',
        'Jμ' => 'construct_flow_name',
        _ => 'construct_vortex_name',
      };

  static MapEntry<String, double> _strongest(HydrodynamicCore c) {
    final scores = _constructScores(c);
    return scores.reduce((a, b) => a.value >= b.value ? a : b);
  }

  static MapEntry<String, double> _weakest(HydrodynamicCore c) {
    final scores = _constructScores(c);
    return scores.reduce((a, b) => a.value <= b.value ? a : b);
  }

  static List<MapEntry<String, double>> _constructScores(HydrodynamicCore c) => [
        MapEntry('ρt', c.continuumScs),
        MapEntry('Jμ', c.flowScs),
        MapEntry('σ', c.shearScs),
        MapEntry('Iτ', c.resistanceScs),
        MapEntry('ω', c.vortexScs),
      ];
}