import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/chronoflux_weight_construal.dart';
import 'package:evolve/services/input_parser.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();
  const construal = ChronofluxWeightConstrual();
  const parser = InputParser();

  test('PART TWO anchors on posed question, not σ/Iτ/Jμ field text', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High shear from polarized protests and rallies.',
      resistanceText: 'Institutional scepticism rising.',
      flowText: 'Trust erosion where nuance is absent.',
    );
    final result = engine.analyze(input);
    final two = result.partTwo;

    expect(two.expandedVortex, contains('civil unrest'));
    expect(two.shearRefinement, contains('civil unrest'));
    expect(two.resistanceFlow, contains('civil unrest'));

    expect(two.shearRefinement.toLowerCase(), isNot(contains('polarized protests')));
    expect(two.resistanceFlow.toLowerCase(), isNot(contains('institutional scepticism')));
    expect(two.resistanceFlow.toLowerCase(), isNot(contains('trust erosion')));
    expect(two.shearRefinement.toLowerCase(), isNot(contains('observed shear')));
  });

  test('PART TWO cites sentience on σ and salience on Iτ', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final result = engine.analyze(input);

    expect(result.partTwo.expandedVortex, contains('% salience'));
    expect(result.partTwo.shearRefinement.toLowerCase(), contains('sentience'));
    expect(result.partTwo.resistanceFlow.toLowerCase(), contains('salience'));
    expect(result.partTwo.shearRefinement, contains('σ'));
    expect(result.partTwo.resistanceFlow, contains('Iτ'));
    expect(result.partTwo.resistanceFlow, contains('Jμ'));
  });

  test('different posed scenarios yield distinct PART TWO narratives', () {
    const unrest = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    const trust = ScenarioInput(
      posedQuestion: 'What percentage trusts the narrative lens near-term?',
    );
    final a = engine.analyze(unrest).partTwo;
    final b = engine.analyze(trust).partTwo;

    expect(a.expandedVortex, isNot(equals(b.expandedVortex)));
    expect(a.shearRefinement, isNot(equals(b.shearRefinement)));
  });

  test('scenario context class shifts weights without supplied σ/Iτ/Jμ fields', () {
    final unrest = construal.construe(const ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    ));
    final policy = construal.construe(const ScenarioInput(
      posedQuestion: 'Will the government publish new policy this month?',
    ));

    expect(unrest.normalized[2], greaterThan(policy.normalized[2]));
    expect(unrest.reasonKeys, contains('weight_reason_context_unrest'));
    expect(policy.reasonKeys, contains('weight_reason_context_institutional'));
  });

  test('enriched weights differ by scenario even when only question changes', () {
    const a = ScenarioInput(
      posedQuestion: 'Will inflation exceed 5% this year?',
    );
    const b = ScenarioInput(
      posedQuestion: 'What percentage trusts the narrative lens near-term?',
    );
    final wa = parser.enrich(a).constructs.map((c) => c.weight).toList();
    final wb = parser.enrich(b).constructs.map((c) => c.weight).toList();
    expect(wa, isNot(equals(wb)));
  });
}