import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/services/synopsis_exporter.dart';

void main() {
  const engine = EvolveEngine();
  const exporter = SynopsisExporter();

  test('percent mode synopsis mirrors MarkdownBin structure for posed scenario', () {
    const input = ScenarioInput(
      topic: 'John Swinney statement on 9 June 2026 protests',
      posedQuestion:
          'What is the chance of sporadic civil unrest following the Belfast knife attack?',
      vortexText:
          'First Minister uniform condemnation of protests in Glasgow, Edinburgh, and Ayr.',
      shearText: 'Pushback on narrative control and selective condemnation.',
      resistanceText: 'Strong institutional legitimacy vs. growing public skepticism.',
      flowText: 'Trajectory toward trust erosion where nuance is absent.',
    );
    final result = engine.analyze(input, mode: AnalysisMode.percentChance);
    final out = LocalizedOutput.of(LocaleConfig.defaults);
    final s = out.strings;

    final synopsis = exporter.export(
      input: input,
      result: result,
      mode: AnalysisMode.percentChance,
      locale: LocaleConfig.defaults,
      createdAt: DateTime(2026, 6, 10, 11, 58, 46),
    );

    expect(synopsis, contains(s.t('cohesion_title').split(':').first));
    expect(synopsis, contains(s.t('cohesion_part_one')));
    expect(synopsis, contains(s.t('cohesion_part_two')));
    expect(synopsis, contains(s.t('cohesion_part_three')));
    expect(synopsis, contains(s.t('synopsis_percent_header')));
    expect(synopsis, contains('${result.percentChance.round()}%'));
    expect(synopsis, contains('regressive percentage, lower chance'));
    expect(synopsis, contains(result.percentPhrase));
    expect(synopsis, contains(result.forecast.forecastLine));
    expect(synopsis, contains(result.partThreeConclusion.headline));
    expect(synopsis, contains(result.partThreeConclusion.actions.first.action));
    expect(synopsis, contains(out.cohesionCycleComplete));
    expect(synopsis, contains(s.t('synopsis_created').split(':').first));
    expect(synopsis, contains('John Swinney statement on 9 June 2026 protests'));
  });

  test('cohesion mode synopsis includes refined score and agent actions', () {
    const input = ScenarioInput(
      posedQuestion: 'How cohesive is public trust after the mayor press conference?',
      vortexText: 'Mayor press conference on downtown safety reforms.',
    );
    final result = engine.analyze(input, mode: AnalysisMode.cohesionScore);
    final s = LocalizedOutput.of(LocaleConfig.defaults).strings;

    final synopsis = exporter.export(
      input: input,
      result: result,
      mode: AnalysisMode.cohesionScore,
      locale: LocaleConfig.defaults,
    );

    expect(synopsis, contains(s.t('synopsis_cohesion_header')));
    expect(synopsis, contains('${result.core.refinedScs.round()}'));
    expect(synopsis, contains(s.t('synopsis_agent_actions')));
    expect(synopsis, contains(s.t('synopsis_mode_cohesion')));
  });
}