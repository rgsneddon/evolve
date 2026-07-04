import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/data/outcome_registry.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/services/outcome_feasibility.dart';
import 'package:evolve/services/scenario_calculation_context.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    OutcomeRegistry.resetForTests();
    await OutcomeRegistry.ensureLoaded();
  });

  const checker = OutcomeFeasibilityChecker();
  const engine = EvolveEngine();

  test('detects Scotland World Cup win as foreclosed', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the percent chance of Scotland winning the World Cup?',
    );
    final feasibility = checker.check(input);
    expect(feasibility.isForeclosed, isTrue);
    expect(feasibility.reason, contains('Scotland'));
  });

  test('open sports question stays feasible', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the percent chance of Brazil winning the World Cup?',
    );
    expect(checker.check(input).isForeclosed, isFalse);
  });

  test('explicit elimination in text marks outcome foreclosed', () {
    const input = ScenarioInput(
      posedQuestion:
          'Can France still win the World Cup after being knocked out?',
    );
    expect(checker.check(input).isForeclosed, isTrue);
  });

  test('foreclosed scenario forces REGRESSIVE lean in calculation context', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the percent chance of Scotland winning the World Cup?',
    );
    final ctx = ScenarioCalculationContext.from(input: input);
    expect(ctx.effectiveLean, 'REGRESSIVE');
  });

  test('Scotland World Cup engine output is regressive near 0%', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the percent chance of Scotland winning the World Cup?',
    );
    final result = engine.analyze(input);
    expect(result.core.lean, 'REGRESSIVE');
    expect(result.percentChance, lessThan(5));
    expect(result.grokStyleReply.toUpperCase(), contains('REGRESSIVE'));
    expect(result.forecast.forecastLine, contains('Foreclosed outcome'));
    expect(result.continuumConclusion.toUpperCase(), contains('REGRESSIVE'));
  });
}