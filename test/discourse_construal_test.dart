import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('protest and economic scenarios get different discourse actions', () {
    final protest = engine.analyze(
      const ScenarioInput(vortexText: 'What is the chance of civil unrest near-term?'),
      mode: AnalysisMode.percentChance,
    );
    final economic = engine.analyze(
      const ScenarioInput(
        topic: 'Transit strike',
        vortexText: 'Will the mayor end the transit strike this month?',
        shearText: 'Unions and riders deeply divided.',
      ),
      mode: AnalysisMode.percentChance,
    );

    expect(protest.partThreeConclusion.actions.first.action.toLowerCase(),
        contains('incident'));
    expect(economic.partThreeConclusion.actions.first.action.toLowerCase(),
        contains('cost-impact'));
    expect(
      protest.partThreeConclusion.actions.first.action,
      isNot(economic.partThreeConclusion.actions.first.action),
    );
  });

  test('Spanish binding summary uses localized labels', () {
    const locale = LocaleConfig(regionId: 'europe', languageCode: 'es');
    final result = engine.analyze(
      const ScenarioInput(
        topic: 'Huelga de transporte',
        vortexText: '¿Probabilidad de protestas en Europa?',
        shearText: 'Polarización.',
      ),
      locale: locale,
    );

    expect(result.partThreeConclusion.contextLine, contains('Europa'));
    expect(result.partThreeConclusion.contextLine.toLowerCase(), contains('protestas'));
    expect(result.cohesionReport, isNot(contains('Topic:')));
  });
}