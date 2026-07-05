import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/grok_session.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/grok_construal_service.dart';
import 'package:evolve/services/grok_heuristic_construal.dart';

void main() {
  test('beginGrokConstrue fills fields from full posed question', () async {
    final provider = EvolveProvider(grokConstrual: const _HeuristicOnlyGrok());
    provider.grokConstrualEnabled = true;
    provider.grokSession = const GrokSession(
      connected: true,
      premium: true,
      screenName: '@test_user',
      mock: false,
    );

    const question =
        'What is the chance of sporadic civil unrest in Glasgow near-term?';
    provider.updateInput(provider.input.copyWith(posedQuestion: question));

    await provider.beginGrokConstrue();

    expect(provider.input.vortexText, contains('ω (vortex):'));
    expect(provider.input.shearText, contains('σ (shear):'));
    expect(provider.input.resistanceText, contains('Iτ (resistance):'));
    expect(provider.input.flowText, contains('Jμ (flow):'));
    expect(provider.input.continuumText, contains('ρt (continuum):'));
    expect(provider.input.vortexText.toLowerCase(), isNot(contains(question.toLowerCase())));
    expect(provider.input.vortexText, isNot(contains('"')));
    expect(provider.input.shearText.toLowerCase(), contains('lever'));
    expect(provider.grokFilledFields.length, 4);
  });

  test('beginGrokConstrue requires grok construal enabled', () async {
    final provider = EvolveProvider();
    provider.updateInput(
      provider.input.copyWith(posedQuestion: 'Will protests escalate?'),
    );

    await provider.beginGrokConstrue();

    expect(provider.input.vortexText, isEmpty);
    expect(provider.statusMessage, isNotNull);
  });
}

class _HeuristicOnlyGrok extends GrokConstrualService {
  const _HeuristicOnlyGrok();

  @override
  Future<GrokConstrualResult> fetchSuggestions({
    required ScenarioInput input,
    required LocaleConfig locale,
    LocalizedOutput? output,
    GrokSession? xSession,
  }) async =>
      GrokHeuristicConstrual.suggest(input: input, locale: locale, output: output);
}