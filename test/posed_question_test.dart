import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/chronoflux_weight_construal.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();
  const construal = ChronofluxWeightConstrual();

  test('posed question anchors semantics; vortex is relative variable', () {
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of civil unrest near-term?',
      vortexText: 'Elite condemnation compresses peaceful protest into disorder.',
    );
    final result = engine.analyze(input);

    expect(result.percentPhrase.toLowerCase(), contains('unrest'));
    expect(result.cohesionReport.toLowerCase(), contains('elite condemnation'));
    final weights = construal.construe(input);
    expect(weights.reasonKeys, contains('weight_reason_posed_question'));
    expect(weights.reasonKeys, contains('weight_reason_vortex_variable'));
    expect(weights.reasonKeys, isNot(contains('weight_reason_shear')));
  });

  test('calculate requires posed question not vortex alone', () async {
    final provider = EvolveProvider();
    provider.updateInput(const ScenarioInput(
      vortexText: 'Shear-only vortex variable without posed question.',
    ));
    await provider.calculate();
    expect(provider.result, isNull);
    expect(provider.statusMessage, isNotNull);
  });
}