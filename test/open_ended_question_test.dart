import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/question_semantics.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('novel question without catalogue keywords gets subject-specific conclusion', () {
    const input = ScenarioInput(
      vortexText: 'Will the mayor resign before autumn?',
    );
    final sem = QuestionSemantics.parse(input);
    final result = engine.analyze(input);

    expect(sem.subject.toLowerCase(), contains('mayor resign'));
    expect(result.percentPhrase.toLowerCase(), contains('mayor resign'));
    expect(result.continuumConclusion.toLowerCase(), contains('mayor resign'));
    expect(result.partThreeConclusion.contextLine.toLowerCase(), contains('mayor'));
    expect(result.partThreeConclusion.actions, hasLength(5));
  });

  test('descriptive scenario without question mark still analyses', () {
    const input = ScenarioInput(
      vortexText: 'Local council housing policy backlash in Manchester this summer',
    );
    final result = engine.analyze(input, mode: AnalysisMode.cohesionScore);

    expect(result.core.vortexScs, isNot(equals(50.0)));
    expect(result.cohesionReport, contains('housing policy backlash'));
    expect(result.partThreeConclusion.actions.first.action, contains('housing'));
  });

  test('unrelated novel questions diverge', () {
    final mayor = engine.analyze(const ScenarioInput(
      vortexText: 'Will the mayor resign before autumn?',
    ));
    final asteroid = engine.analyze(const ScenarioInput(
      vortexText: 'What is the probability of a major asteroid impact this decade?',
    ));

    expect(mayor.percentChance, isNot(equals(asteroid.percentChance)));
    expect(mayor.percentPhrase, isNot(equals(asteroid.percentPhrase)));
    expect(mayor.percentPhrase.toLowerCase(), contains('mayor'));
    expect(asteroid.percentPhrase.toLowerCase(), contains('asteroid'));
  });

  test('percent mode accepts scenario statement without interrogative markers', () {
    const input = ScenarioInput(
      vortexText: 'Regional rail strike escalating through December',
    );
    final result = engine.analyze(input);

    expect(result.percentPhrase, isNotEmpty);
    expect(result.grokStyleReply, contains('CONCLUSION - THE CONTINUUM'));
    expect(result.partThreeConclusion.contextLine.toLowerCase(), contains('rail strike'));
  });
}