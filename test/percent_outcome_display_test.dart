import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('percent outcome subtitle and phrase use REGRESSIVE qualifier', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final result = engine.analyze(input);
    final out = LocalizedOutput.of(const LocaleConfig(regionId: 'global', languageCode: 'en'));

    expect(result.core.lean, 'REGRESSIVE');
    expect(
      out.percentOutcomeSubtitle(lean: out.leanLabel(result.core.lean), regressive: true),
      'REGRESSIVE — regressive percentage, lower chance',
    );
    expect(
      out.percentOutcomePhraseLine(percentPhrase: result.percentPhrase, regressive: true),
      contains('regressive percentage, lower chance'),
    );
    expect(
      out.percentOutcomePhraseLine(percentPhrase: result.percentPhrase, regressive: true),
      contains(result.percentPhrase),
    );
  });

  test('percent outcome subtitle and phrase use PROGRESSIVE qualifier', () {
    const input = ScenarioInput(
      posedQuestion:
          'Will trust and cohesion improve across communities this year?',
      flowText: 'Strong trust transport and unity narratives building.',
    );
    final result = engine.analyze(input);
    final out = LocalizedOutput.of(const LocaleConfig(regionId: 'global', languageCode: 'en'));

    expect(result.core.lean, 'PROGRESSIVE');
    expect(
      out.percentOutcomeSubtitle(lean: out.leanLabel(result.core.lean), regressive: false),
      'PROGRESSIVE — progressive percentage, higher chance',
    );
    expect(
      out.percentOutcomePhraseLine(percentPhrase: result.percentPhrase, regressive: false),
      contains('progressive percentage, higher chance'),
    );
  });
}