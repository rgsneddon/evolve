import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/grok_session.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/grok_construal_service.dart';

import 'test_helpers.dart';

void main() {
  test('new posed question clears prior result and narrative sourceUrl', () async {
    final provider = EvolveProvider();

    provider.updateInput(scenarioWithConstructs(
      shearText: 'High polarisation in media.',
      sourceUrl: 'https://example.com/old-story',
    ));
    await provider.calculate();
    expect(provider.result, isNotNull);

    provider.updateInput(const ScenarioInput(
      posedQuestion: 'Will the mayor win re-election in 2027?',
      shearText: 'High polarisation in media.',
    ));

    expect(provider.result, isNull);
    expect(provider.input.sourceUrl, isEmpty);
    expect(provider.input.posedQuestion, contains('mayor'));
  });

  test('calculate with grok on populates blank construct fields in stored input', () async {
    final grok = _StubGrokConstrual();
    final provider = EvolveProvider(grokConstrual: grok);
    provider.grokConstrualEnabled = true;
    provider.grokSession = const GrokSession(
      connected: true,
      premium: true,
      screenName: 'test',
      mock: true,
    );

    provider.updateInput(const ScenarioInput(
      posedQuestion: 'What is the chance of sporadic civil unrest near-term?',
    ));
    await provider.calculate();

    expect(grok.lastApplied, isTrue);
    expect(provider.input.shearText, contains('Grok-filled shear'));
    expect(provider.input.resistanceText, contains('Grok-filled resistance'));
    expect(provider.result, isNotNull);
  });

  test('second scenario produces distinct outcome from first', () async {
    final provider = EvolveProvider();

    provider.updateInput(scenarioWithConstructs(
      posedQuestion: 'What is the chance of sporadic civil unrest near-term?',
    ));
    await provider.calculate();
    final firstPct = provider.result!.forecast.calibratedPercent;

    provider.updateInput(scenarioWithConstructs(
      posedQuestion: 'Will the mayor win re-election in 2027?',
      vortexText: 'Electoral vortex around incumbency and turnout.',
    ));
    await provider.calculate();
    final secondPct = provider.result!.forecast.calibratedPercent;

    expect(firstPct, isNot(equals(secondPct)));
  });
}

class _StubGrokConstrual extends GrokConstrualService {
  bool lastApplied = false;

  @override
  Future<GrokConstrualResult> fetchSuggestions({
    required ScenarioInput input,
    required LocaleConfig locale,
    LocalizedOutput? output,
  }) async {
    lastApplied = true;
    return const GrokConstrualResult(
      shearText: 'Grok-filled shear should not persist.',
      resistanceText: 'Grok-filled resistance should not persist.',
      provenance: 'test',
    );
  }
}