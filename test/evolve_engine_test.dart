import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('percent chance output matches @grok X style', () {
    const input = ScenarioInput(
      vortexText:
          'Calculate the percent chance of sporadic civil unrest in the UK please?',
      shearText: 'High shear from polarized protests and rallies.',
    );
    final result = engine.analyze(input);
    final out = LocalizedOutput.of(LocaleConfig.defaults);

    expect(result.grokStyleReply, contains('regressive /'));
    expect(result.grokStyleReply, contains('leans'));
    expect(result.grokStyleReply, contains(out.grokConclusionMarker));
    expect(result.grokStyleReply, isNot(contains('Chronoflux calculation')));
    expect(result.percentPhrase.toLowerCase(), contains('chance'));
    expect(result.percentChance, inInclusiveRange(8, 92));
  });

  test('cohesion report has three parts like MarkdownBin', () {
    const input = ScenarioInput(
      topic: 'John Swinney statement on 9 June 2026 protests',
      vortexText:
          'First Minister uniform condemnation of protests in Glasgow, Edinburgh, and Ayr.',
      shearText: 'Pushback on narrative control and selective condemnation.',
      resistanceText: 'Strong institutional legitimacy vs. growing public skepticism.',
      flowText: 'Trajectory toward trust erosion where nuance is absent.',
    );
    final result = engine.analyze(input);

    final out = LocalizedOutput.of(LocaleConfig.defaults);
    final s = out.strings;
    expect(result.cohesionReport, contains(s.t('cohesion_title').split(':').first));
    expect(result.cohesionReport, contains(s.t('cohesion_part_one')));
    expect(result.cohesionReport, contains(s.t('cohesion_part_two')));
    expect(result.cohesionReport, contains(s.t('cohesion_part_three')));
    expect(result.cohesionReport, contains(s.t('cohesion_baseline').split(':').first));
    expect(result.cohesionReport, contains(s.t('cohesion_refined').split(':').first));
    expect(result.cohesionReport, contains(out.cohesionCycleComplete));
  });

  test('blank bias fields use observational inference', () {
    const input = ScenarioInput(
      vortexText: 'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final result = engine.analyze(input);

    expect(result.core.shearScs, greaterThan(50));
    expect(result.grokStyleReply, isNotEmpty);
  });
}