import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/models/evolve_result.dart';
import 'package:evolve/services/party_response_analyzer.dart';
import 'package:evolve/services/party_response_extractor.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/services/synopsis_exporter.dart';

void main() {
  const extractor = PartyResponseExtractor();
  const analyzer = PartyResponseAnalyzer();
  const engine = EvolveEngine();

  const linkedNarrative = '''
First Minister John Swinney said, "We condemn violence in the strongest terms while supporting peaceful protest."
Mayor Jane Doe responded, "The city will increase community policing and dialogue forums."
''';

  test('extractor pulls attributed party quotes from narrative', () {
    final responses = extractor.extract(linkedNarrative);
    expect(responses.length, greaterThanOrEqualTo(2));
    expect(
      responses.any((r) => r.party.toLowerCase().contains('swinney')),
      isTrue,
    );
    expect(
      responses.any((r) => r.excerpt.toLowerCase().contains('community policing')),
      isTrue,
    );
  });

  test('narrativeReliesOnPartyResponses detects attribution reliance', () {
    expect(extractor.narrativeReliesOnPartyResponses(linkedNarrative), isTrue);
    expect(
      extractor.narrativeReliesOnPartyResponses('Short headline only.'),
      isFalse,
    );
  });

  test('cohesion with linked narrative refines SCS from individual party responses', () {
    const input = ScenarioInput(
      topic: 'Protest coverage',
      sourceUrl: 'https://news.test/protests',
      posedQuestion: linkedNarrative,
      shearText: 'Polarized pushback on selective condemnation.',
      resistanceText: 'Institutional legitimacy vs public skepticism.',
      flowText: 'Trajectory toward trust erosion where nuance is absent.',
    );

    final result = engine.analyze(input, mode: AnalysisMode.cohesionScore);
    final refinement = result.partyRefinement;

    expect(refinement, isNotNull);
    expect(refinement!.applied, isTrue);
    expect(refinement.responses.length, greaterThanOrEqualTo(2));
    expect(refinement.refinedNarrativeScs, inInclusiveRange(20, 87));
    expect(result.core.refinedScs, refinement.refinedNarrativeScs);

    final out = LocalizedOutput.of(LocaleConfig.defaults);
    expect(result.cohesionReport, contains(out.strings.t('party_response_section')));
    for (final response in refinement.responses) {
      expect(result.cohesionReport, contains(response.party));
      expect(response.scs, inInclusiveRange(20, 87));
    }
  });

  test('buildRefinement returns null when narrative does not rely on party responses', () {
    const input = ScenarioInput(
      sourceUrl: 'https://news.test/headline',
      posedQuestion: 'City council approves budget without quoted officials.',
    );
    final result = analyzer.buildRefinement(
      input: input,
      responses: const [],
      core: const HydrodynamicCore(
        overallScs: 55,
        baselineScs: 52,
        refinedScs: 54,
        progressivePct: 48,
        regressivePct: 52,
        netMomentum: -0.02,
        lean: 'REGRESSIVE',
        continuumScs: 54,
        flowScs: 53,
        shearScs: 56,
        resistanceScs: 55,
        vortexScs: 54,
        positive: 48,
        dissipative: 52,
      ),
      locale: LocaleConfig.defaults,
    );
    expect(result, isNull);
  });

  test('synopsis export includes party response section for linked cohesion analysis', () {
    const input = ScenarioInput(
      sourceUrl: 'https://news.test/protests',
      posedQuestion: linkedNarrative,
    );
    final result = engine.analyze(input, mode: AnalysisMode.cohesionScore);
    final synopsis = const SynopsisExporter().export(
      input: input,
      result: result,
      mode: AnalysisMode.cohesionScore,
      locale: LocaleConfig.defaults,
    );

    final s = LocalizedOutput.of(LocaleConfig.defaults).strings;
    expect(synopsis, contains(s.t('party_response_section')));
    expect(synopsis, contains(s.t('synopsis_cohesion_header')));
    if (result.partyRefinement != null) {
      expect(synopsis, contains(result.partyRefinement!.summary));
    }
  });
}