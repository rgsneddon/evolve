import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';

import 'test_helpers.dart';

void main() {
  test('switching modes clears unseen tab and restores posed tab both ways', () async {
    final provider = EvolveProvider();

    provider.updateInput(scenarioWithConstructs(
      shearText: 'High polarisation in media.',
    ));
    await provider.calculate();

    expect(provider.mode, AnalysisMode.percentChance);
    expect(provider.input.posedQuestion, contains('unrest'));
    expect(provider.result, isNotNull);

    provider.setMode(AnalysisMode.cohesionScore);
    expect(provider.input.posedQuestion, isEmpty);
    expect(provider.result, isNull);

    provider.updateInput(scenarioWithConstructs(
      topic: 'City protest response',
      posedQuestion: 'Mayor statement on weekend protests.',
      resistanceText: 'Institutional scepticism rising.',
    ));
    await provider.calculate();

    provider.setMode(AnalysisMode.percentChance);
    expect(provider.input.posedQuestion, contains('unrest'));
    expect(provider.input.shearText, contains('polarisation'));
    expect(provider.result, isNotNull);

    provider.setMode(AnalysisMode.cohesionScore);
    expect(provider.input.topic, 'City protest response');
    expect(provider.input.posedQuestion, contains('Mayor'));
    expect(provider.input.resistanceText, contains('scepticism'));
    expect(provider.result, isNotNull);
  });

  test('PART THREE actions reflect full input variables', () async {
    final provider = EvolveProvider();
    provider.updateInput(scenarioWithConstructs(
      topic: 'Transit strike',
      posedQuestion: 'Will the mayor end the transit strike this month?',
      shearText: 'Unions and riders deeply divided.',
      resistanceText: 'City council blocking emergency funds.',
      flowText: 'Rider groups want phased reopening nuance.',
    ));
    await provider.calculate();

    final p3 = provider.result!.partThreeConclusion;
    expect(p3.contextLine.toLowerCase(), contains('transit strike'));
    expect(p3.actions.length, 5);
    expect(p3.actions.every((a) => a.action.contains('mayor')), isTrue);
    expect(p3.targetLabel, contains('→'));
  });
}