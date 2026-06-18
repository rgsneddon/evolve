import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();
  const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');

  test('multi-part question produces listed per-pathway percent breakdown', () {
    const input = ScenarioInput(
      multiPartOutcomeEnabled: true,
      posedQuestion:
          'Give the percent chances of each austerity, stimulus, and status quo '
          'to end the recession?',
    );

    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    expect(result.partBreakdown, isNotNull);
    final breakdown = result.partBreakdown!;
    expect(breakdown.parts.length, 3);
    expect(
      breakdown.parts.map((p) => p.label.toLowerCase()).toSet(),
      {'austerity', 'stimulus', 'status quo'},
    );
    _expectSortedDescending(breakdown.parts.map((p) => p.percentChance).toList());

    expect(breakdown.partitionTotal, 100);

    for (final part in breakdown.parts) {
      expect(part.percentChance, inInclusiveRange(1, 99));
      expect(part.percentPhrase, isNotEmpty);
      expect(part.lean, anyOf('REGRESSIVE', 'PROGRESSIVE'));
    }

    final labels = breakdown.parts.map((p) => p.percentChance).toSet();
    expect(labels.length, greaterThan(1));
  });

  test('non-exhaustive others clause is stripped — only named pathways remain', () {
    const input = ScenarioInput(
      multiPartOutcomeEnabled: true,
      posedQuestion:
          'Percent chances of each hard landing, soft landing, and others '
          '(non-exhaustive) to avoid recession?',
    );

    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    expect(result.partBreakdown, isNotNull);
    expect(result.partBreakdown!.parts.length, 2);
    expect(
      result.partBreakdown!.parts.map((p) => p.label.toLowerCase()).toSet(),
      {'hard landing', 'soft landing'},
    );
    _expectSortedDescending(
      result.partBreakdown!.parts.map((p) => p.percentChance).toList(),
    );
  });

  test('single-outcome question has no part breakdown', () {
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of unrest near-term?',
    );

    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    expect(result.partBreakdown, isNull);
  });

  test('multi-part question text yields single outcome when multi-part disabled', () {
    const input = ScenarioInput(
      posedQuestion:
          'Give the percent chances of each austerity, stimulus, and status quo '
          'to end the recession?',
    );

    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    expect(result.partBreakdown, isNull);
    expect(result.percentChance, isNotNull);
  });
}

void _expectSortedDescending(List<double> shares) {
  for (var i = 0; i < shares.length - 1; i++) {
    expect(shares[i], greaterThanOrEqualTo(shares[i + 1]));
  }
}