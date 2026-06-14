import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/field_calculation_context.dart';
import 'package:evolve/services/input_parser.dart';

void main() {
  const parser = InputParser();

  test('detects supplied construct fields as structural context', () {
    const input = ScenarioInput(
      posedQuestion: 'Chance of unrest near-term?',
      vortexText: 'Elite condemnation framing.',
      shearText: 'Polarized rallies.',
      flowText: 'Trust transport contested.',
    );
    final fields = FieldCalculationContext.from(input);

    expect(fields.hasVortexVariable, isTrue);
    expect(fields.hasShear, isTrue);
    expect(fields.hasResistance, isFalse);
    expect(fields.hasFlow, isTrue);
  });

  test('supplied σ field shifts SCS from question-only baseline', () {
    const base = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    const withShear = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'Institutional scepticism versus street-level grievance framing.',
    );

    final blank = parser.enrich(base);
    final enriched = parser.enrich(withShear);

    expect(enriched.shear.scs, isNot(equals(blank.shear.scs)));
    expect(enriched.shear.weight, greaterThan(blank.shear.weight));
  });
}