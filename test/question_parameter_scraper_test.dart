import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/grok_heuristic_construal.dart';
import 'package:evolve/services/question_parameter_scraper.dart';
import 'package:evolve/services/question_semantics.dart';

void main() {
  test('scrapes subject-anchored construct lines for novel questions', () {
    const question = 'Will the mayor resign before autumn?';
    final sem = QuestionSemantics.fromText(question);
    final fields = QuestionParameterScraper.scrape(
      question: question,
      sem: sem,
    );

    expect(fields['continuum']!, contains('ρt (continuum):'));
    expect(fields['continuum']!, contains('Observed live as of'));
    expect(fields['vortex']!.toLowerCase(), contains('mayor'));
    expect(fields['shear']!.toLowerCase(), contains('mayor'));
    expect(fields['resistance']!, contains('Iτ (resistance):'));
    expect(fields['flow']!, contains('Jμ (flow):'));
  });

  test('heuristic construal fills all blank fields for open-ended question', () {
    const input = ScenarioInput(
      posedQuestion: 'What is the probability of a major asteroid impact this decade?',
    );
    final suggestions = GrokHeuristicConstrual.suggest(
      input: input,
      locale: const LocaleConfig(regionId: 'global', languageCode: 'en'),
    );

    expect(suggestions.continuumText, isNotEmpty);
    expect(suggestions.vortexText, isNotEmpty);
    expect(suggestions.shearText, isNotEmpty);
    expect(suggestions.resistanceText, isNotEmpty);
    expect(suggestions.flowText, isNotEmpty);
    expect(suggestions.vortexText.toLowerCase(), contains('asteroid'));
  });

  test('salientPhrases extracts topic tokens', () {
    final phrases = QuestionParameterScraper.salientPhrases(
      question: 'Chance of housing policy backlash in Manchester',
      topic: 'council budget',
    );

    expect(phrases.any((p) => p.toLowerCase().contains('housing')), isTrue);
    expect(phrases.any((p) => p.toLowerCase().contains('manchester')), isTrue);
  });
}