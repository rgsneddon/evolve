import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/construal_realtime.dart';
import 'package:evolve/services/question_parameter_scraper.dart';
import 'package:evolve/services/question_semantics.dart';

void main() {
  test('ConstrualRealtime prefixes observation lead when missing', () {
    final line = ConstrualRealtime.withLead(
      '2026-07-05',
      'ω (vortex): Authority levers on Glasgow unrest.',
    );
    expect(line, startsWith('Observed live as of 2026-07-05 —'));
  });

  test('QuestionParameterScraper emits real-time continuum and construct lines', () {
    const question =
        'What is the chance of sporadic civil unrest in Glasgow near-term?';
    final sem = QuestionSemantics.fromText(question, regionId: 'uk_ireland');
    final scraped = QuestionParameterScraper.scrape(
      question: question,
      sem: sem,
    );

    for (final construct in ['continuum', 'vortex', 'shear', 'resistance', 'flow']) {
      final line = scraped[construct]!;
      expect(line, contains('Observed live as of'), reason: construct);
      expect(line.toLowerCase(), contains('glasgow'), reason: construct);
    }
    expect(scraped['continuum'], contains('ρt (continuum):'));
  });
}