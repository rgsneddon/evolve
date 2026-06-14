import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';

void main() {
  test('calculate requires all construct fields when grok construal is off', () async {
    final provider = EvolveProvider();
    provider.updateInput(const ScenarioInput(
      posedQuestion: 'What is the chance of civil unrest near-term?',
    ));

    await provider.calculate();

    expect(provider.result, isNull);
    expect(provider.statusMessage, contains('Vortex'));
    expect(provider.statusMessage, contains('Shear'));
  });

  test('ScenarioInput reports missing construct keys', () {
    const input = ScenarioInput(
      posedQuestion: 'Will protests escalate?',
      vortexText: 'Elite framing compresses dissent.',
    );

    expect(input.hasAllConstructTexts, isFalse);
    expect(input.missingConstructKeys, ['shear', 'resistance', 'flow']);
  });
}