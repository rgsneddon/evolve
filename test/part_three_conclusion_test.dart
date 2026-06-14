import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('PART THREE offers five progressive agent actions for unrest', () {
    final result = engine.analyze(
      const ScenarioInput(
        vortexText: 'What is the chance of sporadic civil unrest near-term?',
      ),
      mode: AnalysisMode.percentChance,
    );

    final p3 = result.partThreeConclusion;
    expect(p3.headline, contains('PART THREE'));
    expect(p3.actions.length, 5);
    expect(p3.actions.every((a) => a.action.isNotEmpty), isTrue);
    expect(p3.actions.every((a) => a.rationale.isNotEmpty), isTrue);
    expect(p3.contextLine, isNotEmpty);
    expect(p3.contextLine.toLowerCase(), contains('establishment'));
    expect(p3.headline.toUpperCase(), contains('PROGRESSIVE'));
    expect(p3.headline.toLowerCase(), contains('five'));
    expect(
      p3.actions.last.action.toLowerCase(),
      anyOf(contains('registry'), contains('accountability')),
    );
    expect(
      p3.actions.any((a) => a.action.contains('/100')),
      isTrue,
    );
  });

  test('detects mayor as main agent', () {
    final result = engine.analyze(
      const ScenarioInput(
        vortexText: 'Will the mayor resign before autumn?',
      ),
      mode: AnalysisMode.percentChance,
      locale: const LocaleConfig(regionId: 'americas', languageCode: 'en'),
    );

    expect(result.partThreeConclusion.agentLabel, 'mayor');
    expect(
      result.partThreeConclusion.actions.first.action.toLowerCase(),
      contains('mayor'),
    );
  });

  test('cohesion mode targets SCS with slim actions', () {
    final result = engine.analyze(
      const ScenarioInput(
        topic: 'Protest response',
        vortexText: 'Minister statement on city protests.',
        shearText: 'Polarized pushback on narrative control.',
      ),
      mode: AnalysisMode.cohesionScore,
    );

    final p3 = result.partThreeConclusion;
    expect(p3.headline.toUpperCase(), contains('SCS'));
    expect(p3.agentLabel, 'minister');
    expect(p3.actions.length, 5);
    expect(p3.projectedImpact.toUpperCase(), contains('SCS'));
  });

  test('Spanish locale translates PART THREE actions', () {
    final result = engine.analyze(
      const ScenarioInput(
        vortexText: 'Will the mayor resign before autumn?',
      ),
      locale: const LocaleConfig(regionId: 'global', languageCode: 'es'),
    );

    expect(result.partThreeConclusion.headline, contains('PARTE TRES'));
    expect(
      result.partThreeConclusion.actions.first.action.toLowerCase(),
      contains('rueda de prensa'),
    );
  });
}