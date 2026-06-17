import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/grok_proxy/grok_construct_prompt.dart';

void main() {
  const question =
      'What is the chance of sporadic civil unrest in Glasgow near-term?';

  test('isQuestionEcho detects verbatim question repeat', () {
    expect(
      GrokConstructPrompt.isQuestionEcho(
        'Posed question: "$question"',
        question,
      ),
      isTrue,
    );
    expect(
      GrokConstructPrompt.isQuestionEcho(
        'σ (shear): $question',
        question,
      ),
      isTrue,
    );
  });

  test('sanitizeFields strips echoes and keeps discourse lines', () {
    final cleaned = GrokConstructPrompt.sanitizeFields({
      'vortexText': 'Posed question: "$question"',
      'shearText':
          'σ (shear): Street discourse in Glasgow shows grievance layers sharpening after council statements.',
      'resistanceText': '',
      'flowText':
          'Jμ (flow): Local testimony travels on community pages while official briefings dominate broadcast reach.',
    }, question);

    expect(cleaned['vortexText'], isEmpty);
    expect(cleaned['shearText'], contains('σ (shear)'));
    expect(cleaned['flowText'], contains('Jμ (flow)'));
  });

  test('sanitizeFields strips quoted question parameters from lever lines', () {
    final cleaned = GrokConstructPrompt.sanitizeFields({
      'vortexText':
          'ω (vortex): Elite briefings on "$question" compress authority circulation.',
      'shearText':
          'σ (shear): Grievance-layer levers sharpen partisan split in open channels.',
      'resistanceText': '',
      'flowText': '',
    }, question);

    expect(cleaned['vortexText'], isNot(contains('"')));
    expect(cleaned['vortexText'], contains('ω (vortex)'));
    expect(cleaned['shearText'], contains('lever'));
  });

  test('userMessage instructs lever-only fields not question repeat', () {
    final msg = GrokConstructPrompt.userMessage({
      'posedQuestion': question,
      'regionLabel': 'UK & Ireland',
    });
    expect(msg, contains('do NOT copy'));
    expect(msg, contains('lever-only'));
    expect(msg, contains('no quoted'));
    expect(msg, contains('ω (vortexText)'));
    expect(msg, contains('σ (shearText)'));
    expect(GrokConstructPrompt.systemMessage, contains('lever-only'));
  });
}