import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/data/outcome_registry.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/base_rate_service.dart';
import 'package:evolve/services/event_classifier.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    OutcomeRegistry.resetForTests();
    await OutcomeRegistry.ensureLoaded();
  });

  const engine = EvolveEngine();

  test('event classifier maps unrest to civil_unrest', () {
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of civil unrest in the UK near-term?',
    );
    final c = const EventClassifier().classify(input);
    expect(c.eventClass, 'civil_unrest');
    expect(c.horizonDays, 180);
  });

  test('base rate lookup returns sample size and bounded CI', () {
    final lookup = const BaseRateService().lookup(
      eventClass: 'civil_unrest',
      regionId: 'uk_ireland',
      horizonDays: 180,
    );
    expect(lookup.sampleSize, greaterThan(0));
    expect(lookup.matchedRecords.length, lookup.sampleSize);
    expect(lookup.successCount, lessThanOrEqualTo(lookup.sampleSize));
    expect(lookup.ratePercent, inInclusiveRange(5, 95));
    expect(lookup.ciLow, lessThanOrEqualTo(lookup.ratePercent));
    expect(lookup.ciHigh, greaterThanOrEqualTo(lookup.ratePercent));
  });

  test('calibrated forecast blends base rate and heuristic', () {
    const input = ScenarioInput(
      posedQuestion: 'Chance of recession in the eurozone this year?',
    );
    final result = engine.analyze(input);
    expect(result.forecast.sampleSize, greaterThan(0));
    expect(result.forecast.calibratedPercent, inInclusiveRange(8, 92));
    expect(result.forecast.forecastLine, contains('Calibrated forecast:'));
    expect(result.forecast.forecastLine, contains('95% CI'));
    expect(result.forecast.forecastLine, contains('No betting markets'));
  });

  test('forecast line appears in continuum conclusion for all modes', () {
    const input = ScenarioInput(
      posedQuestion: 'Will protests escalate in Paris this summer?',
    );
    final pct = engine.analyze(input, mode: AnalysisMode.percentChance);
    final coh = engine.analyze(input, mode: AnalysisMode.cohesionScore);

    expect(pct.continuumConclusion, contains('Calibrated REGRESSIVE headline'));
    expect(pct.continuumConclusion, contains('regressive percentage, lower chance'));
    expect(coh.continuumConclusion, contains('Outcome registry'));
    expect(coh.cohesionReport, contains('Weighted Overall SCS'));
    expect(coh.cohesionReport, isNot(contains('THE CONTINUUM — Calibrated Forecast')));
    expect(pct.grokStyleReply, contains('REGRESSIVE outcome'));
    expect(pct.percentChance, pct.forecast.calibratedPercent);
  });

  test('Spanish locale localizes forecast line via English fallback keys', () {
    const input = ScenarioInput(
      posedQuestion: '¿Probabilidad de protestas en Madrid este año?',
    );
    final result = engine.analyze(
      input,
      locale: const LocaleConfig(regionId: 'europe', languageCode: 'es'),
    );
    expect(result.continuumConclusion, contains('pregunta planteada'));
    expect(result.forecast.horizonDays, 365);
  });
}