import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/grok_session.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/pathway_construct_texts.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/grok_construal_service.dart';
import 'package:evolve/services/grok_heuristic_construal.dart';
import 'package:evolve/services/part_pathway_weight_construal.dart';

void main() {
  const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');
  final output = LocalizedOutput.of(locale);

  test('beginGrokConstrue fetches distinct discourse per pathway', () async {
    final provider = EvolveProvider(grokConstrual: const _HeuristicOnlyGrok());
    provider.grokConstrualEnabled = true;
    provider.grokSession = const GrokSession(
      connected: true,
      premium: true,
      screenName: 'test',
      mock: false,
    );
    provider.updateInput(const ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to end the recession',
      outcomeParts: ['austerity', 'stimulus'],
    ));

    await provider.beginGrokConstrue();

    expect(provider.input.pathwayConstruals.length, 2);
    final austerity = provider.input.pathwayConstruals['austerity'];
    final stimulus = provider.input.pathwayConstruals['stimulus'];
    expect(austerity, isNotNull);
    expect(stimulus, isNotNull);
    expect(austerity!.shearText, isNotEmpty);
    expect(stimulus!.shearText, isNotEmpty);
    expect(austerity.shearText.toLowerCase(), isNot(equals(stimulus.shearText.toLowerCase())));
    expect(provider.input.shearText, contains('austerity'));
    expect(provider.input.shearText, contains('stimulus'));
  });

  test('pathway input uses dedicated construal not parent blend', () {
    const parent = ScenarioInput(
      multiPartOutcomeEnabled: true,
      posedQuestion: 'Percent chances of each austerity, stimulus to end recession?',
      shearText: 'σ (shear): Generic parent discourse.',
      pathwayConstruals: {
        'austerity': PathwayConstructTexts(
          shearText: 'σ (shear): Austerity-specific fiscal street discourse.',
        ),
        'stimulus': PathwayConstructTexts(
          shearText: 'σ (shear): Stimulus-specific spending discourse.',
        ),
      },
    );

    final austerityInput = PartPathwayWeightConstrual.pathwayInput(
      parent: parent,
      pathwayLabel: 'austerity',
      subQuestion: 'What is the percent chance of austerity to end recession?',
      locale: locale,
      output: output,
    );

    expect(austerityInput.shearText, contains('Austerity-specific'));
    expect(austerityInput.shearText, isNot(contains('Generic parent')));
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
  }) async {
    return GrokHeuristicConstrual.suggest(
      input: input,
      locale: locale,
      output: output,
    );
  }
}