import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/services/part_pathway_weight_construal.dart';

void main() {
  const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');
  final output = LocalizedOutput.of(locale);
  const engine = EvolveEngine();

  test('pathway input blends parent construal with pathway scrape', () {
    const parent = ScenarioInput(
      posedQuestion: 'Percent chances of each austerity, stimulus to end recession?',
      vortexText: 'ω: Fiscal circulation around recession exit.',
      shearText: 'σ: Street discourse on spending versus cuts.',
    );

    final enriched = const EvolveEngine().parser.enrich(parent, locale: locale, output: output);
    final pathway = PartPathwayWeightConstrual.pathwayInput(
      parent: enriched,
      pathwayLabel: 'austerity',
      subQuestion: 'What is the percent chance of austerity to end recession?',
      locale: locale,
      output: output,
    );

    expect(pathway.shearText.toLowerCase(), contains('austerity'));
    expect(pathway.vortexText, isNotEmpty);
  });

  test('reflective weights diverge across pathways with construal fields', () {
    const input = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to end the recession',
      outcomeParts: ['austerity', 'stimulus'],
      vortexText: 'ω: Recession exit circulation.',
      shearText: 'σ: Polarized fiscal discourse on cuts versus spending.',
      resistanceText: 'Iτ: Treasury scepticism on stimulus scale.',
      flowText: 'Jμ: Public trust in policy narrative.',
    );

    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    expect(result.partBreakdown, isNotNull);
    final shares = result.partBreakdown!.parts.map((p) => p.percentChance).toList();
    expect(shares.length, 2);
    expect(shares.toSet().length, greaterThan(1));
    expect(result.partBreakdown!.partitionTotal, 100);
  });
}