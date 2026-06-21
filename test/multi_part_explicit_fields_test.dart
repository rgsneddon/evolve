import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/services/multi_part_question_parser.dart';

void main() {
  const engine = EvolveEngine();
  const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');

  test('explicit fields ignored when multi-part disabled', () {
    const input = ScenarioInput(
      outcomeContext: 'to end the recession',
      outcomeParts: ['austerity', 'stimulus'],
    );

    expect(MultiPartQuestionParser.fromExplicitFields(input), isNull);
    expect(MultiPartQuestionParser.resolve(input), isNull);
  });

  test('explicit outcome fields build multi-part question', () {
    const input = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to end the recession',
      outcomeParts: ['austerity', 'stimulus', 'status quo'],
    );

    final parsed = MultiPartQuestionParser.fromExplicitFields(input);
    expect(parsed, isNotNull);
    expect(parsed!.parts.length, 3);
    expect(parsed.parts[0].label, 'austerity');
    expect(parsed.parts[1].label, 'stimulus');
    expect(parsed.parts[2].label, 'status quo');
  });

  test('engine produces breakdown from explicit pathway fields', () {
    const input = ScenarioInput(
      multiPartOutcomeEnabled: true,
      posedQuestion: 'Percent chances for each policy pathway',
      outcomeContext: 'to end the recession',
      outcomeParts: ['austerity', 'stimulus', 'status quo'],
    );

    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    expect(result.partBreakdown, isNotNull);
    expect(result.partBreakdown!.parts.length, 3);
    expect(
      result.partBreakdown!.parts.map((p) => p.label.toLowerCase()).toSet(),
      {'austerity', 'stimulus', 'status quo'},
    );
    final shares = result.partBreakdown!.parts.map((p) => p.percentChance).toList();
    for (var i = 0; i < shares.length - 1; i++) {
      expect(shares[i], greaterThanOrEqualTo(shares[i + 1]));
    }
  });

  test('provider calculate accepts two pathway fields without posed question', () async {
    final provider = EvolveProvider();
    provider.mode = AnalysisMode.percentChance;
    provider.updateInput(const ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to avoid recession',
      outcomeParts: ['hard landing', 'soft landing'],
      vortexText: 'ω baseline',
      shearText: 'σ baseline',
      resistanceText: 'Iτ baseline',
      flowText: 'Jμ baseline',
    ));

    await provider.calculate();

    expect(provider.result, isNotNull);
    expect(provider.result!.partBreakdown, isNotNull);
    expect(provider.result!.partBreakdown!.parts.length, 2);
  });
}