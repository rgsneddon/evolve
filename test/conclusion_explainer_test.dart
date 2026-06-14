import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/data/outcome_registry.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/conclusion_explainer.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    OutcomeRegistry.resetForTests();
    await OutcomeRegistry.ensureLoaded();
  });

  const engine = EvolveEngine();
  const locale = LocaleConfig.defaults;

  test('splits grok reply at continuum conclusion', () {
    const input = ScenarioInput(
      vortexText: 'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final result = engine.analyze(input, locale: locale);
    final split = ConclusionExplainer.splitGrokReply(result.grokStyleReply, locale);
    final marker = LocalizedOutput.of(locale).grokConclusionMarker;

    expect(split.body, isNot(contains(marker)));
    expect(split.conclusion, contains(marker));
    expect(
      ConclusionExplainer.percentChance(result, locale: locale),
      contains('%'),
    );
    final explainer = ConclusionExplainer.percentChance(result, locale: locale);
    final bullets = ConclusionExplainer.percentChanceBullets(result, locale);

    expect(explainer, contains('Data points used to construe'));
    expect(explainer, contains('Construal data'));
    expect(explainer, contains('Outcome registry filter'));
    expect(explainer, contains('Exact historical registry cases'));
    expect(bullets, isNotEmpty);
    expect(
      bullets.any((b) => b.startsWith('OR-') || b.startsWith('FB-')),
      isTrue,
    );
  });

  test('splits cohesion report at final summary', () {
    const input = ScenarioInput(
      topic: 'Test scenario',
      vortexText: 'Minister statement on protests.',
      shearText: 'Polarized pushback.',
    );
    final result = engine.analyze(input, locale: locale);
    final split = ConclusionExplainer.splitCohesionReport(result.cohesionReport, locale);
    final out = LocalizedOutput.of(locale);

    expect(split.body, isNot(contains(out.cohesionFinalSummary)));
    expect(split.conclusion, contains(out.cohesionFinalSummary));
    expect(split.conclusion, contains(out.cohesionCycleComplete));
    expect(
      ConclusionExplainer.cohesion(result, locale),
      contains('~'),
    );
    expect(ConclusionExplainer.cohesionBullets(result, locale), isNotEmpty);
  });

  test('Spanish locale localizes grok output', () {
    const es = LocaleConfig(regionId: 'europe', languageCode: 'es');
    final result = engine.analyze(
      const ScenarioInput(vortexText: '¿Probabilidad de protestas en Europa?'),
      locale: es,
    );
    expect(result.grokStyleReply, contains('CONCLUSIÓN'));
    expect(result.percentPhrase, contains('probabilidad'));
  });
}