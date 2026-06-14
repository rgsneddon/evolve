import '../models/analysis_mode.dart';
import '../models/locale_config.dart';
import '../models/construct_input.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import '../l10n/localized_output.dart';
import 'cohesion_report_formatter.dart';
import 'forecast_calibrator.dart';
import 'grok_style_formatter.dart';
import 'chronoflux_weight_construal.dart';
import 'sentience_salience_construal.dart';
import 'conclusion_explainer_data_builder.dart';
import 'continuum_conclusion_builder.dart';
import 'scenario_calculation_context.dart';
import 'input_parser.dart';
import 'part_three_conclusion_formatter.dart';
import 'part_two_narrative_builder.dart';
import 'party_response_analyzer.dart';
import 'party_response_extractor.dart';
import 'scenario_agent_detector.dart';
import 'question_semantics.dart';
import 'scenario_input_profile.dart';
import 'social_discourse_construal.dart';
import '../l10n/app_localizations.dart';
import '../models/party_response_scs.dart';

/// Evolve Chronoflux engine — faithful translation of `chronoflux_restore_sim.py`.
/// Betting odds and polling are NEVER used.
class EvolveEngine {
  const EvolveEngine({
    this.parser = const InputParser(),
    this.forecastCalibrator = const ForecastCalibrator(),
    this.partyResponseAnalyzer = const PartyResponseAnalyzer(),
    this.partyResponseExtractor = const PartyResponseExtractor(),
    this.agentDetector = const ScenarioAgentDetector(),
  });

  final InputParser parser;
  final ForecastCalibrator forecastCalibrator;
  final PartyResponseAnalyzer partyResponseAnalyzer;
  final PartyResponseExtractor partyResponseExtractor;
  final ScenarioAgentDetector agentDetector;

  EvolveResult analyze(
    ScenarioInput raw, {
    AnalysisMode mode = AnalysisMode.percentChance,
    LocaleConfig locale = LocaleConfig.defaults,
  }) {
    final out = LocalizedOutput.of(locale);
    final input = parser.enrich(raw, locale: locale, output: out);
    final narratives = parser.narratives(input, locale: locale, output: out);
    final awareness = _awareness(input, locale);
    final baseline = _hydrodynamicCore(input, awareness);
    final partOne = _partOne(input, narratives, baseline);
    var partTwo = runPartTwo(input, baseline, out, locale, awareness: awareness);
    NarrativePartyRefinement? partyRefinement;
    if (mode == AnalysisMode.cohesionScore && input.sourceUrl.trim().isNotEmpty) {
      partyRefinement = _refineFromPartyResponses(
        input: input,
        core: partTwo.core,
        locale: locale,
        output: out,
      );
      if (partyRefinement != null && partyRefinement.applied) {
        partTwo = _applyPartyRefinement(partTwo, partyRefinement);
      }
    }
    final partThree = _partThree(input, partTwo, out, locale);
    final heuristicPct = _percentChance(partTwo, input, awareness);
    final forecast = forecastCalibrator.calibrate(
      input: input,
      locale: locale,
      heuristicPercent: heuristicPct,
      core: partTwo.core,
      output: out,
    );
    final pct = forecast.calibratedPercent;
    final phrase = _percentPhrase(pct, input, out, locale);
    final continuumConclusion = const ContinuumConclusionBuilder().build(
      input: input,
      locale: locale,
      output: out,
      forecast: forecast,
      core: partTwo.core,
      percentPhrase: phrase,
    );
    final explainerData = const ConclusionExplainerDataBuilder().build(
      input: input,
      locale: locale,
      output: out,
      forecast: forecast,
      core: partTwo.core,
    );

    final grokReply = const GrokStyleFormatter().format(
      input: input,
      core: partTwo.core,
      continuumConclusion: continuumConclusion,
      output: out,
      locale: locale,
    );

    final cohesionReport = CohesionReportFormatter().format(
      input: input,
      core: partTwo.core,
      partOne: partOne,
      partTwo: partTwo,
      partThree: partThree,
      narratives: narratives,
      forecast: forecast,
      output: out,
      partyRefinement: partyRefinement,
    );

    final partThreeConclusion = const PartThreeConclusionFormatter().format(
      mode: mode,
      input: input,
      core: partTwo.core,
      partThree: partThree,
      percentChance: pct,
      forecast: forecast,
      locale: locale,
    );

    return EvolveResult(
      core: partTwo.core,
      partOne: partOne,
      partTwo: partTwo,
      partThree: partThree,
      percentChance: pct,
      percentPhrase: phrase,
      continuumConclusion: continuumConclusion,
      grokStyleReply: grokReply,
      cohesionReport: cohesionReport,
      partThreeConclusion: partThreeConclusion,
      forecast: forecast,
      explainerData: explainerData,
      partyRefinement: partyRefinement,
      partTwoRan: true,
    );
  }

  /// Scores a single attributed party response extracted from a linked narrative.
  HydrodynamicCore scoreResponseFragment({
    required ScenarioInput base,
    required String party,
    required String excerpt,
    LocaleConfig locale = LocaleConfig.defaults,
  }) {
    final out = LocalizedOutput.of(locale);
    final sub = ScenarioInput(
      topic: base.topic,
      sourceUrl: base.sourceUrl,
      posedQuestion: '$party: $excerpt',
      vortexText: excerpt,
    );
    final input = parser.enrich(sub, locale: locale, output: out);
    final awareness = _awareness(input, locale);
    final baseline = _hydrodynamicCore(input, awareness);
    final contextLean = ScenarioCalculationContext.from(
      input: input,
      regionId: locale.regionId,
    ).effectiveLean;
    return _refinedCore(baseline, contextLean: contextLean, awareness: awareness);
  }

  NarrativePartyRefinement? _refineFromPartyResponses({
    required ScenarioInput input,
    required HydrodynamicCore core,
    required LocaleConfig locale,
    required LocalizedOutput output,
  }) {
    final extracted = partyResponseExtractor.extract(input.scenarioQuery);
    if (extracted.isEmpty) return null;

    final strings = output.strings;
    final scores = <PartyResponseScore>[];
    for (final item in extracted) {
      final role = agentDetector.detect(
        scenarioText: item.excerpt,
        topic: item.party,
        locale: locale,
        strings: strings,
      );
      final fragmentCore = scoreResponseFragment(
        base: input,
        party: item.party,
        excerpt: item.excerpt,
        locale: locale,
      );
      scores.add(
        PartyResponseScore(
          party: item.party,
          role: role,
          excerpt: item.excerpt,
          scs: fragmentCore.refinedScs,
          progressivePct: fragmentCore.progressivePct,
          regressivePct: fragmentCore.regressivePct,
          lean: fragmentCore.lean,
        ),
      );
    }

    return partyResponseAnalyzer.buildRefinement(
      input: input,
      responses: scores,
      core: core,
      locale: locale,
      output: output,
    );
  }

  PartTwoSection _applyPartyRefinement(
    PartTwoSection partTwo,
    NarrativePartyRefinement refinement,
  ) {
    final refined = refinement.refinedNarrativeScs;
    final core = partTwo.core;
    final updatedCore = HydrodynamicCore(
      overallScs: core.overallScs,
      baselineScs: core.baselineScs,
      refinedScs: refined,
      progressivePct: core.progressivePct,
      regressivePct: core.regressivePct,
      netMomentum: core.netMomentum,
      lean: core.lean,
      continuumScs: core.continuumScs,
      flowScs: core.flowScs,
      shearScs: core.shearScs,
      resistanceScs: core.resistanceScs,
      vortexScs: core.vortexScs,
      positive: core.positive,
      dissipative: core.dissipative,
      sentiencePct: core.sentiencePct,
      saliencePct: core.saliencePct,
    );
    return PartTwoSection(
      core: updatedCore,
      expandedVortex: partTwo.expandedVortex,
      shearRefinement: partTwo.shearRefinement,
      resistanceFlow: partTwo.resistanceFlow,
      refinedScs: refined,
      progressivePct: partTwo.progressivePct,
      regressivePct: partTwo.regressivePct,
      lean: partTwo.lean,
    );
  }

  /// PART TWO — mandatory continuum integration on every Calculate (both tabs).
  PartTwoSection runPartTwo(
    ScenarioInput input,
    _BaselineCore baseline,
    LocalizedOutput out,
    LocaleConfig locale, {
    SentienceSalienceResult? awareness,
  }) =>
      _partTwo(
        input,
        baseline,
        out,
        locale,
        awareness: awareness ?? _awareness(input, locale),
      );

  SentienceSalienceResult _awareness(ScenarioInput input, LocaleConfig locale) {
    final ctx = ScenarioCalculationContext.from(
      input: input,
      regionId: locale.regionId,
    );
    final weights = const ChronofluxWeightConstrual().construeFromContext(ctx);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: LocalizedOutput.of(locale).regionName(locale.regionId),
    );
    return const SentienceSalienceConstrual().construe(
      context: ctx,
      normalizedWeights: weights.normalized,
      semantics: sem,
    );
  }

  _BaselineCore _hydrodynamicCore(
    ScenarioInput input,
    SentienceSalienceResult awareness,
  ) {
    final e = _effective(input);
    final weightedScs = _weightedScs(input);

    final shearReacted = e.shear * awareness.shearReaction;
    final resistanceReacted = e.resistance * awareness.resistanceReaction;

    final positive = (e.flow + e.vortex + e.continuum * 0.75) / 2.75;
    final dissipative = (shearReacted * 0.62 + resistanceReacted * 0.78) / 1.4;

    var scs = (positive - dissipative * 0.68) * 1.25;
    final lo = (weightedScs - 14).clamp(22.0, 62.0);
    final hi = (weightedScs + 14).clamp(48.0, 90.0);
    scs = scs.clamp(lo, hi).toDouble();

    final progressiveRaw = (positive * 0.82) * (1 - dissipative / 155);
    var regressiveRaw =
        dissipative * 0.95 * (1 + (resistanceReacted - 55) / 140);
    regressiveRaw = regressiveRaw.clamp(28, 45);

    final total = progressiveRaw + regressiveRaw;
    final progressivePct =
        total > 1e-9 ? progressiveRaw / total * 100 : 50.0;
    final regressivePct =
        total > 1e-9 ? regressiveRaw / total * 100 : 50.0;
    final netMomentum = (progressiveRaw - regressiveRaw) / 100;

    return _BaselineCore(
      weightedOverallScs: weightedScs,
      baselineScs: scs,
      positive: positive,
      dissipative: dissipative,
      progressivePct: progressivePct,
      regressivePct: regressivePct,
      netMomentum: netMomentum,
      lean: netMomentum >= 0 ? 'PROGRESSIVE' : 'REGRESSIVE',
      effective: e,
      input: input,
    );
  }

  HydrodynamicCore _refinedCore(
    _BaselineCore baseline, {
    required String contextLean,
    required SentienceSalienceResult awareness,
  }) {
    final input = baseline.input;
    final constructive = (input.vortex.scs + input.flow.scs) / 2;
    final shearReacted = input.shear.scs * awareness.shearReaction;
    final resistanceReacted = input.resistance.scs * awareness.resistanceReaction;
    final dissipativeChannel = (shearReacted + resistanceReacted) / 2;

    final refinedPositive = (constructive + baseline.positive) / 2;
    final refinedDissipative =
        (dissipativeChannel * 0.68 + baseline.dissipative) / 1.68;
    final eliteFactor = 1 + (shearReacted + resistanceReacted) / 300;
    final mechanicalBaseline = (input.vortex.scs +
            input.shear.scs +
            input.resistance.scs +
            input.flow.scs) /
        4;

    var refinedScs = ((refinedPositive - refinedDissipative * 0.68) *
            1.25 *
            eliteFactor)
        .clamp(mechanicalBaseline * 0.85, mechanicalBaseline * 1.15);

    if (input.hasQuestion) {
      refinedScs = (refinedScs * 0.55 + input.vortex.scs * 0.45).clamp(20, 87);
    } else {
      refinedScs = refinedScs.clamp(20, 87);
    }

    final progRaw = (refinedPositive * 0.82) * (1 - refinedDissipative / 155);
    var regRaw = refinedDissipative *
        0.95 *
        (1 + (resistanceReacted - 55) / 140);
    regRaw = regRaw.clamp(28, 55);

    final total = progRaw + regRaw;
    var progPct = total > 1e-9 ? progRaw / total * 100 : 50.0;
    var regPct = total > 1e-9 ? regRaw / total * 100 : 50.0;

    if (contextLean == 'REGRESSIVE' && progPct >= regPct) {
      progPct -= 2;
      regPct += 2;
    } else if (contextLean == 'PROGRESSIVE' && regPct >= progPct) {
      progPct += 2;
      regPct -= 2;
    }

    final net = (progPct - regPct) / 100;

    return HydrodynamicCore(
      overallScs: baseline.weightedOverallScs,
      baselineScs: baseline.baselineScs,
      refinedScs: refinedScs,
      progressivePct: progPct,
      regressivePct: regPct,
      netMomentum: net,
      lean: contextLean,
      continuumScs: input.continuum.scs,
      flowScs: input.flow.scs,
      shearScs: input.shear.scs,
      resistanceScs: input.resistance.scs,
      vortexScs: input.vortex.scs,
      positive: refinedPositive,
      dissipative: refinedDissipative,
      sentiencePct: awareness.sentiencePct,
      saliencePct: awareness.saliencePct,
    );
  }

  _Effective _effective(ScenarioInput input) {
    final w = _normalizedWeights(input.constructs);
    final c = input.constructs;
    double eff(int i) => (c[i].scs * w[i] * 5).clamp(0, 100);

    return _Effective(
      continuum: eff(0),
      flow: eff(1),
      shear: eff(2),
      resistance: eff(3),
      vortex: eff(4),
    );
  }

  double _weightedScs(ScenarioInput input) {
    final w = _normalizedWeights(input.constructs);
    final scs = input.constructs.map((c) => c.scs).toList();
    var sum = 0.0;
    for (var i = 0; i < 5; i++) {
      sum += scs[i] * w[i];
    }
    return sum;
  }

  List<double> _normalizedWeights(List<ConstructInput> constructs) {
    final total = constructs.fold(0.0, (a, c) => a + c.weight);
    if (total < 1e-9) return List.filled(5, 0.2);
    return constructs.map((c) => c.weight / total).toList();
  }

  PartOneSection _partOne(
    ScenarioInput input,
    Map<String, String> narratives,
    _BaselineCore baseline,
  ) =>
      PartOneSection(
        vortex: narratives['vortex']!,
        shear: narratives['shear']!,
        resistance: narratives['resistance']!,
        flow: narratives['flow']!,
        overallScs: baseline.weightedOverallScs,
        baselineScs: baseline.baselineScs,
        progressivePct: baseline.progressivePct,
        regressivePct: baseline.regressivePct,
      );

  PartTwoSection _partTwo(
    ScenarioInput input,
    _BaselineCore baseline,
    LocalizedOutput out,
    LocaleConfig locale, {
    required SentienceSalienceResult awareness,
  }) {
    final calcCtx = ScenarioCalculationContext.from(
      input: input,
      regionId: locale.regionId,
    );
    final core = _refinedCore(
      baseline,
      contextLean: calcCtx.effectiveLean,
      awareness: awareness,
    );
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );
    final weights = const ChronofluxWeightConstrual().construeFromContext(calcCtx);
    final partTwoText = const PartTwoNarrativeBuilder().build(
      input: input,
      sem: sem,
      out: out,
      normalizedWeights: weights.normalized,
      core: core,
    );
    return PartTwoSection(
      core: core,
      expandedVortex: partTwoText.expandedVortex,
      shearRefinement: partTwoText.shearRefinement,
      resistanceFlow: partTwoText.resistanceFlow,
      refinedScs: core.refinedScs,
      progressivePct: core.progressivePct,
      regressivePct: core.regressivePct,
      lean: core.lean,
    );
  }

  PartThreeSection _partThree(
    ScenarioInput input,
    PartTwoSection two,
    LocalizedOutput out,
    LocaleConfig locale,
  ) {
    final strings = AppLocalizations.of(locale);
    final profile = ScenarioInputProfile.from(input: input, core: two.core, locale: locale);
    const construal = SocialDiscourseConstrual();

    final without = two.refinedScs;
    final mechanicalBaseline = (input.vortex.scs +
            input.shear.scs +
            input.resistance.scs +
            input.flow.scs) /
        4;
    final flowLift = input.flow.scs / 100;
    final withMin = input.applyLevers
        ? (mechanicalBaseline * 0.72 + flowLift * 14).clamp(56, 63)
        : without;
    final withMax =
        (withMin + (input.vortex.scs + input.flow.scs) / 50).clamp(56, 65);

    return PartThreeSection(
      interventions: construal.slimInterventions(
        profile: profile,
        strings: strings,
      ),
      withoutLeversScs: without,
      withLeversMin: withMin.toDouble(),
      withLeversMax: withMax.toDouble(),
      recurrenceRisk: out.recurrenceRisk(without < 45),
    );
  }

  /// Chronoflux headline % — regressive continuum × 0.55 + σ × 0.25 + strain × 0.2.
  static double heuristicPercentChance({
    required double regressivePct,
    required double refinedScs,
    required double shearScs,
  }) =>
      (regressivePct * 0.55 + shearScs * 0.25 + (100 - refinedScs) * 0.2).clamp(8, 92);

  double _percentChance(
    PartTwoSection two,
    ScenarioInput input,
    SentienceSalienceResult awareness,
  ) =>
      heuristicPercentChance(
        regressivePct: two.regressivePct,
        refinedScs: two.refinedScs,
        shearScs: input.shear.scs * awareness.shearReaction,
      );

  String _percentPhrase(
    double pct,
    ScenarioInput input,
    LocalizedOutput out,
    LocaleConfig locale,
  ) {
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );
    return out.percentPhrase(sem.frame, pct.round(), sem.displaySubject);
  }

}

class _Effective {
  const _Effective({
    required this.continuum,
    required this.flow,
    required this.shear,
    required this.resistance,
    required this.vortex,
  });

  final double continuum;
  final double flow;
  final double shear;
  final double resistance;
  final double vortex;
}

class _BaselineCore {
  const _BaselineCore({
    required this.weightedOverallScs,
    required this.baselineScs,
    required this.positive,
    required this.dissipative,
    required this.progressivePct,
    required this.regressivePct,
    required this.netMomentum,
    required this.lean,
    required this.effective,
    required this.input,
  });

  final double weightedOverallScs;
  final double baselineScs;
  final double positive;
  final double dissipative;
  final double progressivePct;
  final double regressivePct;
  final double netMomentum;
  final String lean;
  final _Effective effective;
  final ScenarioInput input;
}