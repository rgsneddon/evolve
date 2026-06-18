import '../models/locale_config.dart';
import '../services/question_semantics.dart';
import 'app_localizations.dart';

/// All calculation/output text in the user's selected language.
class LocalizedOutput {
  const LocalizedOutput(this.strings);

  final AppLocalizations strings;

  factory LocalizedOutput.of(LocaleConfig locale) =>
      LocalizedOutput(AppLocalizations.of(locale));

  String get grokConclusionMarker => strings.t('grok_conclusion_marker');
  String get cohesionFinalSummary => strings.t('cohesion_final_summary');
  String get cohesionCycleComplete => strings.t('cohesion_cycle_complete');

  String regionName(String regionId) => strings.t('region_$regionId');

  String regionFocusBanner(String regionId) => strings
      .t('region_focus_banner')
      .replaceAll('{region}', regionName(regionId));

  String percentPhrase(QuestionFrame frame, int n, String subject) {
    final key = switch (frame) {
      QuestionFrame.probability => 'pct_probability',
      QuestionFrame.predictive => 'pct_predictive',
      QuestionFrame.magnitude => 'pct_magnitude',
      QuestionFrame.descriptive => 'pct_descriptive',
    };
    return strings.t(key).replaceAll('{n}', '$n').replaceAll('{subject}', subject);
  }

  String cohesionState(bool regressive) =>
      strings.t(regressive ? 'cohesion_strained' : 'cohesion_favourable');

  String leanLabel(String lean) =>
      strings.t(lean == 'PROGRESSIVE' ? 'lean_progressive' : 'lean_regressive');

  String driversHighShear(String snippet) =>
      strings.t('drivers_high_shear').replaceAll('{snippet}', snippet);

  String driversHighShearSubject(String subject) => strings
      .t('drivers_high_shear_subject')
      .replaceAll('{subject}', subject);

  String driversDefault(String subject, String lean) => strings
      .t('drivers_default')
      .replaceAll('{subject}', subject)
      .replaceAll('{lean}', leanLabel(lean));

  String observedVortex(String subject, int scs, String regionName) => strings
      .t('obs_vortex')
      .replaceAll('{subject}', subject)
      .replaceAll('{scs}', '$scs')
      .replaceAll('{region}', regionName);

  String observedVortexRelative(
    String subject,
    String vortexVar,
    int scs,
    String region,
  ) =>
      strings
          .t('obs_vortex_relative')
          .replaceAll('{subject}', subject)
          .replaceAll('{vortex}', vortexVar)
          .replaceAll('{scs}', '$scs')
          .replaceAll('{region}', region);

  String observedShear(String subject, int scs, String region) => strings
      .t('obs_shear')
      .replaceAll('{subject}', subject)
      .replaceAll('{scs}', '$scs')
      .replaceAll('{region}', region);

  String observedResistance(String subject, int scs, String region) => strings
      .t('obs_resistance')
      .replaceAll('{subject}', subject)
      .replaceAll('{scs}', '$scs')
      .replaceAll('{region}', region);

  String observedFlow(String subject, int scs, String region) => strings
      .t('obs_flow')
      .replaceAll('{subject}', subject)
      .replaceAll('{scs}', '$scs')
      .replaceAll('{region}', region);

  String shearFallback() => strings.t('obs_shear_fallback');
  String resistanceFallback() => strings.t('obs_resistance_fallback');
  String flowFallback() => strings.t('obs_flow_fallback');

  String partTwoExpandedVortex({
    required String question,
    required String subject,
    required String topic,
    required int weightPct,
    required int scs,
    required QuestionFrame frame,
  }) {
    final key = topic.isNotEmpty
        ? 'part_two_vortex_topic'
        : 'part_two_vortex_question';
    return strings
        .t(key)
        .replaceAll('{question}', question)
        .replaceAll('{subject}', subject)
        .replaceAll('{topic}', topic)
        .replaceAll('{weight}', '$weightPct')
        .replaceAll('{scs}', '$scs')
        .replaceAll('{frame}', _partTwoFrameLabel(frame));
  }

  String partTwoShearRefinement({
    required String question,
    required String subject,
    required int weightPct,
    required int scs,
    required QuestionFrame frame,
    required OutcomePolarity polarity,
    required String dominantHint,
  }) {
    var line = strings
        .t('part_two_shear_question')
        .replaceAll('{question}', question)
        .replaceAll('{subject}', subject)
        .replaceAll('{weight}', '$weightPct')
        .replaceAll('{scs}', '$scs')
        .replaceAll('{frame}', _partTwoFrameLabel(frame))
        .replaceAll('{polarity}', _partTwoPolarityLabel(polarity));
    if (dominantHint.isNotEmpty) {
      line += ' ${strings.t('part_two_hint_suffix').replaceAll('{hint}', dominantHint)}';
    }
    return line;
  }

  String partTwoResistanceFlow({
    required String question,
    required String subject,
    required int resistanceWeightPct,
    required int flowWeightPct,
    required int resistanceScs,
    required int flowScs,
    required String lean,
    required OutcomePolarity polarity,
    required String dominantHint,
  }) {
    var line = strings
        .t('part_two_resistance_flow_question')
        .replaceAll('{question}', question)
        .replaceAll('{subject}', subject)
        .replaceAll('{res_weight}', '$resistanceWeightPct')
        .replaceAll('{flow_weight}', '$flowWeightPct')
        .replaceAll('{res_scs}', '$resistanceScs')
        .replaceAll('{flow_scs}', '$flowScs')
        .replaceAll('{lean}', leanLabel(lean))
        .replaceAll('{transport}', _partTwoTransportLabel(resistanceScs, flowScs, polarity));
    if (dominantHint.isNotEmpty) {
      line += ' ${strings.t('part_two_hint_suffix').replaceAll('{hint}', dominantHint)}';
    }
    return line;
  }

  String partTwoFrameLabel(QuestionFrame frame) => _partTwoFrameLabel(frame);

  String partTwoPolarityLabel(OutcomePolarity polarity) =>
      _partTwoPolarityLabel(polarity);

  String _partTwoFrameLabel(QuestionFrame frame) => switch (frame) {
        QuestionFrame.probability => strings.t('part_two_frame_probability'),
        QuestionFrame.predictive => strings.t('part_two_frame_predictive'),
        QuestionFrame.magnitude => strings.t('part_two_frame_magnitude'),
        QuestionFrame.descriptive => strings.t('part_two_frame_descriptive'),
      };

  String _partTwoPolarityLabel(OutcomePolarity polarity) => switch (polarity) {
        OutcomePolarity.adverse => strings.t('part_two_polarity_adverse'),
        OutcomePolarity.favourable => strings.t('part_two_polarity_favourable'),
        OutcomePolarity.open => strings.t('part_two_polarity_open'),
      };

  String _partTwoTransportLabel(
    int resistanceScs,
    int flowScs,
    OutcomePolarity polarity,
  ) {
    if (flowScs >= resistanceScs + 8) {
      return strings.t('part_two_transport_flow_dominant');
    }
    if (resistanceScs >= flowScs + 8) {
      return strings.t('part_two_transport_resistance_dominant');
    }
    if (polarity == OutcomePolarity.adverse) {
      return strings.t('part_two_transport_contested_adverse');
    }
    return strings.t('part_two_transport_contested');
  }

  String weightConstrualLine(List<String> reasonKeys) {
    if (reasonKeys.isEmpty) return strings.t('weight_construal_default');
    final parts = reasonKeys.map(strings.t).join('; ');
    return strings.t('weight_construal_intro').replaceAll('{reasons}', parts);
  }

  String forecastLine({
    required int pct,
    required int ciLow,
    required int ciHigh,
    required String subject,
    required int horizonDays,
    required int sampleSize,
    required int yearMin,
    required int yearMax,
    required double brier,
    required int refinedScs,
    required double regressivePct,
    required String provenance,
  }) =>
      strings
          .t('forecast_line')
          .replaceAll('{pct}', '$pct')
          .replaceAll('{ci_low}', '$ciLow')
          .replaceAll('{ci_high}', '$ciHigh')
          .replaceAll('{subject}', subject)
          .replaceAll('{horizon}', '$horizonDays')
          .replaceAll('{sample}', '$sampleSize')
          .replaceAll('{year_min}', '$yearMin')
          .replaceAll('{year_max}', '$yearMax')
          .replaceAll('{brier}', brier.toStringAsFixed(2))
          .replaceAll('{refined}', '$refinedScs')
          .replaceAll('{regressive}', regressivePct.toStringAsFixed(1))
          .replaceAll('{provenance}', provenance);

  String eventClassLabel(String eventClass) =>
      strings.t('event_class_$eventClass');

  String grokReply({
    required double regressivePct,
    required double progressivePct,
    required String momentum,
    required String lean,
    required String continuumConclusion,
  }) =>
      strings
          .t('grok_reply')
          .replaceAll('{regressive}', regressivePct.toStringAsFixed(1))
          .replaceAll('{progressive}', progressivePct.toStringAsFixed(1))
          .replaceAll('{momentum}', momentum)
          .replaceAll('{lean}', leanLabel(lean))
          .replaceAll('{conclusion}', continuumConclusion)
          .replaceAll('{marker}', grokConclusionMarker);

  String recurrenceRisk(bool high) =>
      strings.t(high ? 'recurrence_high' : 'recurrence_moderate');

  String continuumHintsClause(String hints) =>
      strings.t('continuum_hints_clause').replaceAll('{hints}', hints);

  /// Lists each OR-xxxx registry row used in the base-rate calculation.
  String registryCasesElaboration({
    required int sampleSize,
    required int successCount,
    required List<String> caseLines,
  }) {
    if (sampleSize <= 0 || caseLines.isEmpty) {
      return strings.t('explainer_registry_cases_empty');
    }
    return strings
        .t('continuum_registry_cases_elaboration')
        .replaceAll('{n}', '$sampleSize')
        .replaceAll('{successes}', '$successCount')
        .replaceAll('{cases}', caseLines.join('; '));
  }

  String continuumOutcomeQualifier(bool regressive) => strings.t(
        regressive ? 'continuum_outcome_regressive' : 'continuum_outcome_progressive',
      );

  String percentOutcomeSubtitle({
    required String lean,
    required bool regressive,
  }) =>
      strings
          .t('percent_outcome_subtitle')
          .replaceAll('{lean}', lean)
          .replaceAll('{qualifier}', continuumOutcomeQualifier(regressive));

  /// Calibrated Chronoflux headline % (same formula as Percent Chance tab).
  int cohesionContinuumHeadlinePercent(double percentChance) =>
      percentChance.round();

  /// Lean + calibrated headline % under the big SCS score.
  String cohesionContinuumSubtitle({
    required String lean,
    required int pct,
  }) =>
      strings.t('cohesion_continuum_subtitle').replaceAll('{lean}', lean).replaceAll('{pct}', '$pct');

  String percentOutcomePhraseLine({
    required String percentPhrase,
    required bool regressive,
  }) =>
      strings
          .t('percent_outcome_phrase')
          .replaceAll('{phrase}', percentPhrase)
          .replaceAll('{qualifier}', continuumOutcomeQualifier(regressive));

  String partBreakdownTitle() => strings.t('part_breakdown_title');

  String partBreakdownOutcome(String outcome) =>
      strings.t('part_breakdown_outcome').replaceAll('{outcome}', outcome);

  String partBreakdownOthersLabel() => strings.t('part_breakdown_others');

  String partBreakdownNote() => strings.t('part_breakdown_note');

  String partBreakdownTotal(int total) =>
      strings.t('part_breakdown_total').replaceAll('{total}', '$total');

  String partBreakdownSharePhrase({
    required int share,
    required String pathway,
    required String outcomeContext,
    required QuestionFrame frame,
    required String displaySubject,
  }) {
    if (outcomeContext.trim().isNotEmpty) {
      return strings
          .t('part_breakdown_share_phrase')
          .replaceAll('{n}', '$share')
          .replaceAll('{pathway}', pathway)
          .replaceAll('{outcome}', outcomeContext.trim());
    }
    return strings
        .t('part_breakdown_share_only')
        .replaceAll('{n}', '$share')
        .replaceAll('{pathway}', pathway);
  }

  String partBreakdownLeanLine({
    required String lean,
    required bool regressive,
    required int regressivePct,
    required int progressivePct,
  }) =>
      strings
          .t('part_breakdown_lean_line')
          .replaceAll('{lean}', lean)
          .replaceAll('{qualifier}', continuumOutcomeQualifier(regressive))
          .replaceAll('{reg}', '$regressivePct')
          .replaceAll('{prog}', '$progressivePct');

  String synopsisPartBreakdownHeader() => strings.t('synopsis_part_breakdown_header');

  String continuumOutcomeLead({
    required String percentPhrase,
    required int calibratedPct,
    required String lean,
    required bool regressive,
  }) =>
      strings
          .t('continuum_outcome_lead')
          .replaceAll('{percent_phrase}', percentPhrase)
          .replaceAll('{pct}', '$calibratedPct')
          .replaceAll('{lean}', lean)
          .replaceAll('{outcome_qualifier}', continuumOutcomeQualifier(regressive));

  String continuumConclusion({
    required String percentPhrase,
    required String question,
    required QuestionFrame frame,
    required OutcomePolarity polarity,
    required String eventClass,
    required int horizonDays,
    required String region,
    required String hintsClause,
    required int vortexScs,
    required int shearScs,
    required int resistanceScs,
    required int flowScs,
    required int weightVortexPct,
    required int weightShearPct,
    required int weightResistancePct,
    required int weightFlowPct,
    required int refinedScs,
    required int regressivePct,
    required int progressivePct,
    required String lean,
    required String baseRatePct,
    required int sampleSize,
    required int yearMin,
    required int yearMax,
    required int histCiLow,
    required int histCiHigh,
    required String brier,
    required String provenance,
    required int calibratedPct,
    required int ciLow,
    required int ciHigh,
    required String heuristicPct,
    required int baseWeightPct,
    required int heuristicWeightPct,
    required bool regressive,
    required int successCount,
    required List<String> matchedCaseLines,
  }) {
    final outcomeQualifier = continuumOutcomeQualifier(regressive);
    final outcomeLead = continuumOutcomeLead(
      percentPhrase: percentPhrase,
      calibratedPct: calibratedPct,
      lean: lean,
      regressive: regressive,
    );

    final signals = strings
        .t('continuum_conclusion_signals')
        .replaceAll('{question}', question)
        .replaceAll('{frame}', _partTwoFrameLabel(frame))
        .replaceAll('{polarity}', _partTwoPolarityLabel(polarity))
        .replaceAll('{event_class}', eventClass)
        .replaceAll('{horizon}', '$horizonDays')
        .replaceAll('{region}', region)
        .replaceAll('{hints_clause}', hintsClause);

    final constructs = strings
        .t('continuum_conclusion_constructs')
        .replaceAll('{vortex_scs}', '$vortexScs')
        .replaceAll('{shear_scs}', '$shearScs')
        .replaceAll('{res_scs}', '$resistanceScs')
        .replaceAll('{flow_scs}', '$flowScs')
        .replaceAll('{w_v}', '$weightVortexPct')
        .replaceAll('{w_s}', '$weightShearPct')
        .replaceAll('{w_r}', '$weightResistancePct')
        .replaceAll('{w_f}', '$weightFlowPct')
        .replaceAll('{refined}', '$refinedScs')
        .replaceAll('{reg}', '$regressivePct')
        .replaceAll('{prog}', '$progressivePct')
        .replaceAll('{lean}', lean);

    final registry = strings
        .t('continuum_conclusion_registry')
        .replaceAll('{event_class}', eventClass)
        .replaceAll('{base_rate}', baseRatePct)
        .replaceAll('{n}', '$sampleSize')
        .replaceAll('{year_min}', '$yearMin')
        .replaceAll('{year_max}', '$yearMax')
        .replaceAll('{hist_ci_low}', '$histCiLow')
        .replaceAll('{hist_ci_high}', '$histCiHigh')
        .replaceAll('{brier}', brier)
        .replaceAll('{sources}', provenance)
        .replaceAll('{horizon}', '$horizonDays');

    final casesElaboration = registryCasesElaboration(
      sampleSize: sampleSize,
      successCount: successCount,
      caseLines: matchedCaseLines,
    );

    final calibration = strings
        .t('continuum_conclusion_calibration')
        .replaceAll('{lean}', lean)
        .replaceAll('{outcome_qualifier}', outcomeQualifier)
        .replaceAll('{pct}', '$calibratedPct')
        .replaceAll('{ci_low}', '$ciLow')
        .replaceAll('{ci_high}', '$ciHigh')
        .replaceAll('{base_w}', '$baseWeightPct')
        .replaceAll('{base_rate}', baseRatePct)
        .replaceAll('{heur_w}', '$heuristicWeightPct')
        .replaceAll('{heuristic_pct}', heuristicPct);

    return '$outcomeLead $signals $constructs $registry $casesElaboration $calibration';
  }

  String partyRefinementSummary({
    required int count,
    required int before,
    required int after,
    required int weightPct,
  }) =>
      strings
          .t('party_refinement_summary')
          .replaceAll('{count}', '$count')
          .replaceAll('{before}', '$before')
          .replaceAll('{after}', '$after')
          .replaceAll('{weight}', '$weightPct');

  String partyResponsePanelTitle() => strings.t('party_response_panel_title');

  String intervention(int index) => strings.t('intervention_$index');

  String explainerPercent({
    required int pct,
    required String subjectClause,
    required double reg,
    required int shear,
    required int strain,
    required String momentum,
    required String lean,
    required bool progressive,
    required String forecastLine,
  }) =>
      strings
          .t('explainer_percent')
          .replaceAll('{pct}', '$pct')
          .replaceAll('{subject_clause}', subjectClause)
          .replaceAll('{reg}', reg.toStringAsFixed(1))
          .replaceAll('{shear}', '$shear')
          .replaceAll('{strain}', '$strain')
          .replaceAll('{momentum}', momentum)
          .replaceAll('{lean}', leanLabel(lean))
          .replaceAll('{transport}', strings.t(progressive ? 'transport_progressive' : 'transport_regressive'))
          .replaceAll('{forecast_line}', forecastLine);

  String explainerCohesion({
    required int refined,
    required int baseline,
    required String deltaWord,
    required int prog,
    required int reg,
    required bool progressive,
    required int withMin,
    required int withMax,
    required int without,
    required String recurrence,
  }) =>
      strings
          .t('explainer_cohesion')
          .replaceAll('{refined}', '$refined')
          .replaceAll('{baseline}', '$baseline')
          .replaceAll('{delta_word}', deltaWord)
          .replaceAll('{prog}', '$prog')
          .replaceAll('{reg}', '$reg')
          .replaceAll('{momentum}', strings.t(progressive ? 'momentum_repair' : 'momentum_friction'))
          .replaceAll('{with_min}', '$withMin')
          .replaceAll('{with_max}', '$withMax')
          .replaceAll('{without}', '$without')
          .replaceAll('{recurrence}', recurrence);

  String constructBullet(String symbol, int scs, String label) => strings
      .t('construct_bullet')
      .replaceAll('{symbol}', symbol)
      .replaceAll('{scs}', '$scs')
      .replaceAll('{label}', label);

  String cohesionDeltaWord(int delta) {
    if (delta > 2) return strings.t('delta_improved');
    if (delta < -2) return strings.t('delta_strained');
    return strings.t('delta_held');
  }
}