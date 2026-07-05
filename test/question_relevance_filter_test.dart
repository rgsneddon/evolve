import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/grok_field_sanitizer.dart';
import 'package:evolve/services/grok_proxy/grok_construct_prompt.dart';
import 'package:evolve/services/question_relevance_filter.dart';

void main() {
  const question =
      'What is the chance of sporadic civil unrest in Glasgow near-term?';
  const subject = 'sporadic civil unrest in Glasgow near-term';

  test('drops off-topic data sentences lacking question overlap', () {
    final cleaned = QuestionRelevanceFilter.enforceFieldRelevance(
      'σ (shear): Paris metro strikes intensify. '
      'Glasgow protest rhetoric sharpens grievance layers after council statements.',
      posedQuestion: question,
      displaySubject: subject,
      rawSubject: subject,
    );

    expect(cleaned.toLowerCase(), isNot(contains('paris')));
    expect(cleaned.toLowerCase(), contains('glasgow'));
  });

  test('strips generic lever lines lacking question token overlap', () {
    final cleaned = GrokFieldSanitizer.sanitizeField(
      'σ (shear): Grievance-layer levers sharpen partisan split in open channels.',
      posedQuestion: question,
      displaySubject: subject,
    );

    expect(cleaned, isEmpty);
  });

  test('keeps construct lever lines that cite question subject', () {
    final cleaned = GrokFieldSanitizer.sanitizeField(
      'σ (shear): Grievance-layer levers on Glasgow unrest sharpen '
      'partisan split in open channels.',
      posedQuestion: question,
      displaySubject: subject,
    );

    expect(cleaned, contains('σ (shear)'));
    expect(cleaned.toLowerCase(), contains('glasgow'));
    expect(cleaned, isNotEmpty);
  });

  test('filters UI-only regional hint labels from construal data points', () {
    final hints = QuestionRelevanceFilter.questionDerivedHints([
      'collective-disorder circulation',
      'regional-scope-uk_ireland',
      'foreign-geo-suppressed-uk_ireland',
      'regional-ω-anchor-uk_ireland',
    ]);

    expect(hints, contains('collective-disorder circulation'));
    expect(hints, isNot(contains('regional-scope-uk_ireland')));
    expect(hints, isNot(contains('foreign-geo-suppressed-uk_ireland')));
  });

  test('grok prompt requires real-time question-only analysis', () {
    expect(GrokConstructPrompt.systemMessage, contains('REAL-TIME'));
    expect(GrokConstructPrompt.systemMessage, contains('WHOLLY RELEVANT'));
    expect(GrokConstructPrompt.systemMessage, contains('ongoing events'));
    expect(GrokConstructPrompt.systemMessage, contains('continuumText'));
  });
}