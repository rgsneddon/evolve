import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/evolve_engine.dart';

import 'test_helpers.dart';

void main() {
  const engine = EvolveEngine();

  test('calculate on percent tab runs PART TWO', () async {
    final provider = EvolveProvider();
    provider.updateInput(scenarioWithConstructs(
      posedQuestion: 'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High shear from polarized protests.',
    ));
    await provider.calculate();

    expect(provider.result!.partTwoRan, isTrue);
    expect(provider.result!.partTwo.expandedVortex, isNotEmpty);
    expect(provider.result!.partTwo.refinedScs, inInclusiveRange(20, 87));
  });

  test('calculate on cohesion tab runs PART TWO', () async {
    final provider = EvolveProvider();
    provider.setMode(AnalysisMode.cohesionScore);
    provider.updateInput(scenarioWithConstructs(
      topic: 'City protest response',
      posedQuestion: 'Mayor statement on weekend protests.',
      resistanceText: 'Institutional scepticism rising.',
    ));
    await provider.calculate();

    expect(provider.result!.partTwoRan, isTrue);
    expect(provider.result!.partTwo.shearRefinement, isNotEmpty);
    final out = LocalizedOutput.of(LocaleConfig.defaults);
    expect(provider.result!.cohesionReport, contains(out.strings.t('cohesion_part_two')));
  });

  test('engine runPartTwo produces refined core distinct from baseline', () {
    const input = ScenarioInput(
      posedQuestion: 'Will inflation exceed 5% this year?',
      shearText: 'Household cost pressure and media friction.',
      flowText: 'Trust erosion where nuance is absent.',
    );
    final result = engine.analyze(input);

    expect(result.partTwo.refinedScs, isNot(equals(result.partOne.baselineScs)));
    expect(result.core.refinedScs, equals(result.partTwo.refinedScs));
    expect(result.core.lean, equals(result.partTwo.lean));
  });
}