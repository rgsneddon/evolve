import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  test('region change does not pre-fill posed question', () {
    final provider = EvolveProvider();
    expect(provider.input.posedQuestion, isEmpty);

    provider.setLocale(const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'));
    expect(provider.input.posedQuestion, isEmpty);

    provider.setLocale(const LocaleConfig(regionId: 'europe', languageCode: 'en'));
    expect(provider.input.posedQuestion, isEmpty);
  });

  test('region anchors observations in outputs', () {
    const engine = EvolveEngine();
    const question = 'What is the chance of policy backlash near-term?';
    final global = engine.analyze(
      const ScenarioInput(posedQuestion: question),
      locale: const LocaleConfig(regionId: 'global', languageCode: 'en'),
    );
    final europe = engine.analyze(
      const ScenarioInput(posedQuestion: question),
      locale: const LocaleConfig(regionId: 'europe', languageCode: 'en'),
    );

    expect(global.partThreeConclusion.contextLine, contains('Global'));
    expect(europe.partThreeConclusion.contextLine, contains('Europe'));
    expect(europe.cohesionReport, contains('in Europe'));
    expect(europe.cohesionReport, isNot(contains('in Global')));
  });

  test('localized cohesion report uses translated headers', () {
    const engine = EvolveEngine();
    const locale = LocaleConfig(regionId: 'global', languageCode: 'es');
    final strings = AppLocalizations.of(locale);
    final out = LocalizedOutput.of(locale);
    final result = engine.analyze(
      const ScenarioInput(
        vortexText: 'Declaración del ministro sobre protestas.',
        shearText: 'Polarización.',
      ),
      mode: AnalysisMode.cohesionScore,
      locale: locale,
    );

    expect(result.cohesionReport, contains(strings.t('cohesion_part_one')));
    expect(result.cohesionReport, contains(out.cohesionConclusionHeading));
    expect(result.cohesionReport, contains(strings.t('cohesion_weighted_panel')));
    expect(result.cohesionReport, isNot(contains('### Vortex (Initial Conditions)')));
  });
}