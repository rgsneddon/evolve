import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('different ω questions produce different percent chances', () {
    final unrest = engine.analyze(const ScenarioInput(
      vortexText: 'What is the chance of sporadic civil unrest in the UK near-term?',
    ));
    final trust = engine.analyze(const ScenarioInput(
      vortexText: 'What percentage trusts the narrative lens near-term?',
    ));
    final inflation = engine.analyze(const ScenarioInput(
      vortexText: 'Will inflation exceed 5% this year?',
    ));

    expect(unrest.percentChance, isNot(equals(trust.percentChance)));
    expect(trust.percentChance, isNot(equals(inflation.percentChance)));
    expect(unrest.core.vortexScs, isNot(equals(trust.core.vortexScs)));
    expect(unrest.percentPhrase.toLowerCase(), contains('unrest'));
    expect(trust.percentPhrase.toLowerCase(), contains('narrative lens'));
    expect(inflation.percentPhrase.toLowerCase(), contains('inflation'));
  });

  test('re-running same question gives consistent output', () {
    const input = ScenarioInput(
      vortexText: 'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final a = engine.analyze(input);
    final b = engine.analyze(input);
    expect(a.percentChance, equals(b.percentChance));
    expect(a.core.vortexScs, equals(b.core.vortexScs));
  });
}