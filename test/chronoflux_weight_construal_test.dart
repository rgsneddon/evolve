import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/chronoflux_weight_construal.dart';
import 'package:evolve/services/input_parser.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const construal = ChronofluxWeightConstrual();
  const parser = InputParser();
  const engine = EvolveEngine();

  List<double> norm(ScenarioInput input) =>
      construal.construe(input).normalized;

  test('supplied shear field raises σ weight — prose wording is immaterial', () {
    const base = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    const withShear = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High shear from polarized protests and rallies.',
    );

    final baseNorm = norm(base);
    final shearNorm = norm(withShear);

    expect(shearNorm[2], greaterThan(baseNorm[2]));
    final enriched = parser.enrich(withShear);
    final enrichedBase = parser.enrich(base);
    expect(enriched.shear.weight, greaterThan(enrichedBase.shear.weight));
    expect(construal.construe(withShear).reasonKeys, contains('weight_reason_shear'));
  });

  test('different scenario contexts yield different normalized weights', () {
    final unrest = norm(const ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    ));
    final trust = norm(const ScenarioInput(
      posedQuestion: 'What percentage trusts the narrative lens near-term?',
    ));
    final institutional = norm(const ScenarioInput(
      posedQuestion: 'Will the government publish new policy this month?',
    ));

    expect(unrest, isNot(equals(trust)));
    expect(institutional[3], greaterThan(unrest[3]));
  });

  test('normalized weights sum to 1', () {
    final result = construal.construe(const ScenarioInput(
      posedQuestion: 'Calculate the percent chance of inflation exceeding 5%?',
    ));
    final sum = result.normalized.fold(0.0, (a, w) => a + w);
    expect(sum, closeTo(1.0, 1e-9));
  });

  test('weight construal still applies non-flat weights in pipeline', () {
    const input = ScenarioInput(
      posedQuestion:
          'Calculate the percent chance of sporadic civil unrest in the UK please?',
    );
    final result = engine.analyze(input);
    final out = LocalizedOutput.of(LocaleConfig.defaults);
    final construal = const ChronofluxWeightConstrual().construe(input);

    expect(construal.summary, contains('σ='));
    expect(construal.summary, contains('ω='));
    expect(construal.summary, isNot(contains('w=0.2')));
    expect(result.grokStyleReply, contains(out.grokConclusionMarker));
    expect(result.grokStyleReply, isNot(contains('context weights')));
  });
}