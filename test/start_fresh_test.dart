import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/providers/evolve_provider.dart';

import 'test_helpers.dart';

void main() {
  test('startFresh clears inputs, results, and saved mode state', () async {
    final provider = EvolveProvider();

    provider.updateInput(scenarioWithConstructs());
    await provider.calculate();
    expect(provider.result, isNotNull);

    provider.setMode(AnalysisMode.cohesionScore);
    provider.updateInput(scenarioWithConstructs(
      posedQuestion: 'Mayor statement on weekend protests.',
    ));
    await provider.calculate();

    provider.startFresh();

    expect(provider.mode, AnalysisMode.cohesionScore);
    expect(provider.input.posedQuestion, isEmpty);
    expect(provider.input.vortexText, isEmpty);
    expect(provider.input.shearText, isEmpty);
    expect(provider.result, isNull);
    expect(provider.grokFilledFields, isEmpty);
    expect(provider.freshSession, 1);
    expect(provider.statusMessage, isNull);
  });
}