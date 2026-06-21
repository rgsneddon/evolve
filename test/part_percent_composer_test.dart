import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/services/part_percent_composer.dart';

void main() {
  const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');
  final output = LocalizedOutput.of(locale);

  test('normalizeTo100 uses largest-remainder and sums to 100', () {
    final shares = PartPercentComposer.normalizeTo100ForTest([30, 40, 35]);
    expect(shares.fold<int>(0, (a, b) => a + b), 100);
    expect(shares.length, 3);
  });

  test('calibratedPartitionWeights nudges clustered forecasts without wild spread', () {
    final refined = PartPercentComposer.calibratedPartitionWeightsForTest([48, 49, 50]);
    final shares = PartPercentComposer.normalizeTo100ForTest([48, 49, 50]);
    final spread = shares.reduce((a, b) => a > b ? a : b) -
        shares.reduce((a, b) => a < b ? a : b);
    expect(spread, lessThan(12));
    expect(refined[0], closeTo(48, 3));
    expect(refined[2], closeTo(50, 3));
  });

  test('shares track calibrated proportions for separated forecasts', () {
    final shares = PartPercentComposer.normalizeTo100ForTest([62, 38]);
    expect(shares, [62, 38]);
  });

  test('compose assigns relative leans from continuum momentum', () {
    final breakdown = PartPercentComposer.compose(
      drafts: const [
        PartPercentDraft(
          label: 'Austerity',
          subQuestion: 'What is the percent chance of austerity to end recession?',
          rawCalibrated: 62,
          partitionWeight: 62,
          regressivePct: 58,
          progressivePct: 42,
          refinedScs: 44,
          shearScs: 60,
        ),
        PartPercentDraft(
          label: 'Stimulus',
          subQuestion: 'What is the percent chance of stimulus to end recession?',
          rawCalibrated: 38,
          partitionWeight: 38,
          regressivePct: 40,
          progressivePct: 60,
          refinedScs: 56,
          shearScs: 38,
        ),
      ],
      outcomeContext: 'to end the recession',
      output: output,
      locale: locale,
    );

    expect(breakdown.partitionTotal, 100);
    expect(breakdown.parts.first.lean, 'REGRESSIVE');
    expect(breakdown.parts.last.lean, 'PROGRESSIVE');
    expect(breakdown.parts.first.percentChance, greaterThan(breakdown.parts.last.percentChance));
    expect(breakdown.parts.first.percentChance, closeTo(62, 2));
    expect(breakdown.parts.last.percentChance, closeTo(38, 2));
  });

  test('compose orders pathways highest to lowest share', () {
    final breakdown = PartPercentComposer.compose(
      drafts: const [
        PartPercentDraft(
          label: 'Stimulus',
          subQuestion: 'What is the percent chance of stimulus to end recession?',
          rawCalibrated: 38,
          partitionWeight: 38,
          regressivePct: 40,
          progressivePct: 60,
          refinedScs: 56,
          shearScs: 38,
        ),
        PartPercentDraft(
          label: 'Austerity',
          subQuestion: 'What is the percent chance of austerity to end recession?',
          rawCalibrated: 62,
          partitionWeight: 62,
          regressivePct: 58,
          progressivePct: 42,
          refinedScs: 44,
          shearScs: 60,
        ),
      ],
      outcomeContext: 'to end the recession',
      output: output,
      locale: locale,
    );

    expect(breakdown.parts.first.label, 'Austerity');
    expect(breakdown.parts.last.label, 'Stimulus');
    expect(
      breakdown.parts.first.percentChance,
      greaterThan(breakdown.parts.last.percentChance),
    );
  });

  test('multi-part engine breakdown partitions to 100%', () {
    const engine = EvolveEngine();
    const input = ScenarioInput(
      multiPartOutcomeEnabled: true,
      posedQuestion: 'Percent chances of each austerity, stimulus, and status quo to end recession?',
      outcomeParts: ['austerity', 'stimulus', 'status quo'],
      outcomeContext: 'to end the recession',
    );

    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    expect(result.partBreakdown, isNotNull);
    expect(result.partBreakdown!.partitionTotal, 100);
    for (final part in result.partBreakdown!.parts) {
      expect(part.percentChance, inInclusiveRange(1, 99));
      expect(part.lean, anyOf('REGRESSIVE', 'PROGRESSIVE'));
      expect(part.percentPhrase.toLowerCase(), contains('share'));
    }
  });
}