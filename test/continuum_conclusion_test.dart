import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/data/outcome_registry.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    OutcomeRegistry.resetForTests();
    await OutcomeRegistry.ensureLoaded();
  });

  const engine = EvolveEngine();

  test('continuum conclusion cites posed question and registry data points', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final result = engine.analyze(input);
    final conclusion = result.continuumConclusion;

    expect(conclusion, contains('posed question'));
    expect(conclusion, contains('civil unrest'));
    expect(conclusion, contains('180-day horizon'));
    expect(conclusion, contains('Outcome registry'));
    expect(conclusion, contains('Exact historical cases underpinning'));
    expect(conclusion, contains('OR-'));
    expect(conclusion, contains('Wilson'));
    expect(conclusion, contains('Brier'));
    expect(conclusion, contains('ω'));
    expect(conclusion, contains('σ'));
    expect(conclusion, contains('Calibrated REGRESSIVE headline'));
    expect(conclusion, contains('regressive percentage, lower chance'));
    expect(conclusion, contains('60%'));
    expect(conclusion, contains('40%'));
    expect(conclusion.toLowerCase(), isNot(contains('ω/σ/iτ/jμ dynamics')));
  });

  test('continuum conclusion ignores σ field text in favour of question signals', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High shear from polarized protests and rallies.',
    );
    final result = engine.analyze(input);

    expect(result.continuumConclusion, contains('posed question'));
    expect(
      result.continuumConclusion.toLowerCase(),
      isNot(contains('polarized protests')),
    );
  });

  test('different questions produce distinct continuum construal data', () {
    const unrest = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    const policy = ScenarioInput(
      posedQuestion: 'Will the government publish new policy this month?',
    );
    final a = engine.analyze(unrest).continuumConclusion;
    final b = engine.analyze(policy).continuumConclusion;

    expect(a, isNot(equals(b)));
    expect(a, contains('civil unrest'));
    expect(b.toLowerCase(), contains('policy'));
  });

  test('Spanish locale localizes continuum conclusion structure', () {
    const input = ScenarioInput(
      posedQuestion: '¿Probabilidad de protestas en Madrid este año?',
    );
    final result = engine.analyze(
      input,
      locale: const LocaleConfig(regionId: 'europe', languageCode: 'es'),
    );

    expect(result.continuumConclusion, contains('pregunta planteada'));
    expect(result.continuumConclusion, contains('Titular REGRESSIVE calibrado'));
    expect(result.continuumConclusion, contains('porcentaje regresivo, menor probabilidad'));
    expect(result.grokStyleReply, contains('CONCLUSIÓN'));
  });

  test('REGRESSIVE lean labels outcome with lower-chance qualifier', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final result = engine.analyze(input);

    expect(result.core.lean, 'REGRESSIVE');
    expect(result.continuumConclusion, contains('REGRESSIVE outcome'));
    expect(result.continuumConclusion, contains('regressive percentage, lower chance'));
    expect(result.continuumConclusion, contains('Calibrated REGRESSIVE headline'));
  });

  test('PROGRESSIVE lean labels outcome with higher-chance qualifier', () {
    const input = ScenarioInput(
      posedQuestion:
          'Will trust and cohesion improve across communities this year?',
      flowText: 'Strong trust transport and unity narratives building.',
    );
    final result = engine.analyze(input);

    expect(result.core.lean, 'PROGRESSIVE');
    expect(result.continuumConclusion, contains('PROGRESSIVE outcome'));
    expect(result.continuumConclusion, contains('progressive percentage, higher chance'));
    expect(result.continuumConclusion, contains('Calibrated PROGRESSIVE headline'));
  });

  test('grok reply conclusion block contains explicit construal data', () {
    const input = ScenarioInput(
      posedQuestion: 'Will inflation exceed 5% this year?',
    );
    final result = engine.analyze(input);
    final out = LocalizedOutput.of(LocaleConfig.defaults);
    final marker = out.grokConclusionMarker;
    final idx = result.grokStyleReply.indexOf(marker);

    expect(idx, greaterThan(0));
    final conclusion = result.grokStyleReply.substring(idx);
    expect(conclusion, contains('Outcome registry'));
    expect(conclusion, contains('inflation'));
  });
}