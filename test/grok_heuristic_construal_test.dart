import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/grok_heuristic_construal.dart';

void main() {
  test('GrokHeuristicConstrual fills blank fields only', () {
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of unrest near-term?',
      shearText: 'User shear bias.',
    );
    final suggestions = GrokHeuristicConstrual.suggest(
      input: input,
      locale: const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'),
    );

    expect(suggestions.shearText, 'User shear bias.');
    const fullQuestion = 'What is the chance of unrest near-term?';
    expect(suggestions.vortexText, startsWith('ω (vortex):'));
    expect(suggestions.resistanceText, startsWith('Iτ (resistance):'));
    expect(suggestions.flowText, startsWith('Jμ (flow):'));
    expect(suggestions.vortexText.toLowerCase(), isNot(contains(fullQuestion.toLowerCase())));
    expect(suggestions.provenance, 'grok-heuristic-web');
  });
}