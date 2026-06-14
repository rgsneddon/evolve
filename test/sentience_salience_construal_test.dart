import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/chronoflux_weight_construal.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/services/question_semantics.dart';
import 'package:evolve/services/scenario_calculation_context.dart';
import 'package:evolve/services/sentience_salience_construal.dart';

void main() {
  const construal = SentienceSalienceConstrual();
  const weights = ChronofluxWeightConstrual();
  const engine = EvolveEngine();

  SentienceSalienceResult awarenessFor(ScenarioInput input) {
    final ctx = ScenarioCalculationContext.from(input: input);
    final w = weights.construeFromContext(ctx);
    final sem = QuestionSemantics.parse(input);
    return construal.construe(
      context: ctx,
      normalizedWeights: w.normalized,
      semantics: sem,
    );
  }

  test('sentience exceeds salience for civil unrest polarisation scenario', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High polarisation across rallies.',
    );
    final awareness = awarenessFor(input);

    expect(awareness.sentiencePct, greaterThan(awareness.saliencePct));
    expect(awareness.shearReaction, greaterThan(0.45));
    expect(awareness.shearReaction, lessThanOrEqualTo(1.0));
    expect(awareness.reasonKeys, contains('sentience_reason_unrest'));
  });

  test('salience exceeds sentience for institutional resistance scenario', () {
    const input = ScenarioInput(
      posedQuestion: 'How likely is a recession in the eurozone this year?',
      resistanceText: 'ECB institutional inertia and policy drag.',
    );
    final awareness = awarenessFor(input);

    expect(awareness.saliencePct, greaterThan(awareness.sentiencePct));
    expect(awareness.resistanceReaction, greaterThan(0.45));
    expect(awareness.reasonKeys, contains('salience_reason_economic'));
  });

  test('awareness shifts hydrodynamic core and percent chance headline', () {
    const withShear = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'scs=78',
    );
    const withResistance = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      resistanceText: 'scs=78',
    );

    final shearResult = engine.analyze(withShear);
    final resistanceResult = engine.analyze(withResistance);

    expect(shearResult.core.sentiencePct, greaterThan(resistanceResult.core.sentiencePct));
    expect(resistanceResult.core.saliencePct, greaterThan(shearResult.core.saliencePct));
    expect(shearResult.percentChance, isNot(equals(resistanceResult.percentChance)));
  });

  test('PART TWO narratives cite sentience on σ and salience on Iτ', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final result = engine.analyze(input);

    expect(result.partTwo.shearRefinement.toLowerCase(), contains('sentience'));
    expect(result.partTwo.resistanceFlow.toLowerCase(), contains('salience'));
    expect(result.partTwo.shearRefinement, isNot(contains('salience')));
  });
}