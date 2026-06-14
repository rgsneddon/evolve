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

  test('userMessage instructs discourse grounding not question repeat', () {
    final msg = GrokConstructPrompt.userMessage({
      'posedQuestion': question,
      'regionLabel': 'UK & Ireland',
    });
    expect(msg, contains('do NOT copy'));
    expect(msg, contains('ω (vortexText)'));
    expect(msg, contains('σ (shearText)'));
  });
}