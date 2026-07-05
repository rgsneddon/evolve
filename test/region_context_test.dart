import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/data/outcome_registry.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/region_context.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('RegionContext scopes subjects without foreign geography', () {
    const ctx = RegionContext('uk_ireland');
    expect(
      ctx.scopeSubject('policy backlash near-term', 'UK & Ireland'),
      'policy backlash near-term — UK & Ireland focus',
    );
    expect(
      ctx.scopeSubject('sporadic civil unrest in the UK', 'UK & Ireland'),
      'sporadic civil unrest in the UK',
    );
    expect(ctx.hasForeignGeography('protests in France escalate'), isTrue);
    expect(ctx.textMatchesRegion('protests in Glasgow'), isTrue);
  });

  test('uk_ireland and europe produce distinct regional outputs for same question', () {
    const question = 'What is the chance of policy backlash near-term?';
    final uk = engine.analyze(
      ScenarioInput(posedQuestion: question),
      locale: const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'),
    );
    final eu = engine.analyze(
      ScenarioInput(posedQuestion: question),
      locale: const LocaleConfig(regionId: 'europe', languageCode: 'en'),
    );

    expect(uk.cohesionReport, contains('UK & Ireland'));
    expect(eu.cohesionReport, contains('Europe'));
    expect(uk.cohesionReport, isNot(contains('in Global')));
    expect(eu.cohesionReport, isNot(contains('in Global')));
    expect(uk.core.refinedScs, isNot(eu.core.refinedScs));
  });

  test('user construct fields are region-scoped in cohesion report', () {
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of institutional pushback near-term?',
      shearText: 'Elite narrative compression on migration policy.',
    );
    final result = engine.analyze(
      input,
      mode: AnalysisMode.cohesionScore,
      locale: const LocaleConfig(regionId: 'mena', languageCode: 'en'),
    );

    expect(result.cohesionReport, contains('Middle East & North Africa focus'));
    expect(result.cohesionReport, contains('Elite narrative compression on migration policy'));
    expect(result.cohesionReport, contains('in Middle East & North Africa'));
  });

  test('outcome registry strict matching excludes other regions', () {
    OutcomeRegistry.resetForTests();
    final registry = OutcomeRegistry.bundled();
    final ukHits = registry.matching(
      eventClass: 'civil_unrest',
      regionId: 'uk_ireland',
      horizonDays: 180,
    );
    expect(ukHits.every((r) => r.regionId == 'uk_ireland'), isTrue);
    expect(ukHits.any((r) => r.regionId == 'global'), isFalse);
  });

  test('scoped display subject appears in forecast for selected region', () {
    final out = LocalizedOutput.of(
      const LocaleConfig(regionId: 'oceania', languageCode: 'en'),
    );
    final result = engine.analyze(
      const ScenarioInput(
        posedQuestion: 'What is the chance of community tensions near-term?',
      ),
      locale: const LocaleConfig(regionId: 'oceania', languageCode: 'en'),
    );

    expect(
      result.forecast.forecastLine,
      contains('Oceania focus'),
    );
    expect(out.regionName('oceania'), 'Oceania');
  });
}