import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';

void main() {
  test('cohesion calculate does not require posed question when vortex is filled', () async {
    final provider = EvolveProvider();
    provider.mode = AnalysisMode.cohesionScore;
    provider.updateInput(const ScenarioInput(
      vortexText:
          'Mayor press conference on weekend protests — liaison forums convened after ward-level disorder.',
      shearText: 'Polarised commentary on enforcement versus assembly rights.',
      resistanceText: 'Council scrutiny of public-order decision timelines.',
      flowText: 'Community trust transport diverges across affected wards.',
    ));

    await provider.calculate();

    expect(provider.result, isNotNull);
    expect(provider.statusMessage, isNot(contains('POSE YOUR QUESTION HERE')));
  });

  test('cohesion calculate still requires some scenario content', () async {
    final provider = EvolveProvider();
    provider.mode = AnalysisMode.cohesionScore;

    await provider.calculate();

    expect(provider.result, isNull);
    expect(provider.statusMessage, contains('narrative link'));
  });

  test('percent chance still requires posed question', () async {
    final provider = EvolveProvider();
    provider.updateInput(const ScenarioInput(
      vortexText: 'Regional rail strike escalating through December.',
      shearText: 'Union and management narratives diverge.',
      resistanceText: 'Parliamentary review of settlement terms.',
      flowText: 'Passenger trust in operator communications.',
    ));

    await provider.calculate();

    expect(provider.result, isNull);
    expect(provider.statusMessage, contains('POSE YOUR QUESTION HERE'));
  });
}