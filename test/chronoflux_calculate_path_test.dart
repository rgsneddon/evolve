import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

/// Thin regression on the shipped Chronoflux calculate entry:
/// posed question + region → calibrated percent/SCS outcome + five PART THREE actions.
void main() {
  const engine = EvolveEngine();

  test('percent mode: posed question + region yields calibrated percent and five actions',
      () {
    final result = engine.analyze(
      const ScenarioInput(
        posedQuestion:
            'What is the chance of sustained social cohesion recovery in the next quarter?',
      ),
      mode: AnalysisMode.percentChance,
      locale: const LocaleConfig(regionId: 'europe', languageCode: 'en'),
    );

    expect(result.percentPhrase, isNotEmpty);
    expect(result.percentChance, isNot(equals(0.0)));
    expect(result.percentChance, inInclusiveRange(0.0, 100.0));
    expect(result.partThreeConclusion.actions, hasLength(5));
    expect(
      result.partThreeConclusion.actions.every((a) => a.action.trim().isNotEmpty),
      isTrue,
    );
    expect(result.partThreeConclusion.contextLine, contains('Europe'));
  });

  test('cohesion mode: region scenario yields non-empty SCS path and five PART THREE actions',
      () {
    final result = engine.analyze(
      const ScenarioInput(
        posedQuestion: 'How cohesive is public trust after the rail disruption?',
        vortexText: 'Regional rail disruption and ministerial briefings.',
      ),
      mode: AnalysisMode.cohesionScore,
      locale: const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'),
    );

    expect(result.cohesionReport, isNotEmpty);
    expect(result.core.vortexScs, isNotNull);
    expect(result.partThreeConclusion.actions, hasLength(5));
    expect(
      result.partThreeConclusion.actions.every((a) => a.rationale.isNotEmpty),
      isTrue,
    );
  });
}
