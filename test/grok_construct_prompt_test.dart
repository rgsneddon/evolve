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
          'Jμ (flow): Glasgow community testimony travels on local pages while official briefings dominate broadcast reach.',
    }, question);

    expect(cleaned['vortexText'], isEmpty);
    expect(cleaned['shearText'], contains('σ (shear)'));
    expect(cleaned['flowText'], contains('Jμ (flow)'));
  });

  test('sanitizeFields strips quoted question parameters from lever lines', () {
    final cleaned = GrokConstructPrompt.sanitizeFields({
      'vortexText':
          'ω (vortex): Elite briefings on Glasgow unrest compress authority circulation.',
      'shearText':
          'σ (shear): Grievance-layer levers on Glasgow unrest sharpen partisan split.',
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
    expect(GrokConstructPrompt.systemMessage, contains('WHOLLY RELEVANT'));
    expect(GrokConstructPrompt.systemMessage, contains('DISCOURSE AUDIT'));
  });

  test('userMessage includes discourse audit checklist', () {
    final msg = GrokConstructPrompt.userMessage({
      'posedQuestion': question,
      'regionLabel': 'UK & Ireland',
    });
    expect(msg, contains('DISCOURSE AUDIT CHECKLIST'));
    expect(msg, contains('Search X and open discourse'));
    expect(msg, contains('Every non-empty field must name'));
  });

  test('userMessage includes sibling pathway contrast for multi-part construal', () {
    final msg = GrokConstructPrompt.userMessage({
      'posedQuestion':
          'What is the percent chance of austerity to end the recession?',
      'parentPosedQuestion':
          'Percent chances of each austerity, stimulus to end recession?',
      'pathwayLabel': 'austerity',
      'siblingPathwayLabels': ['stimulus'],
      'outcomeContext': 'to end the recession',
      'multiPartPathway': true,
      'regionLabel': 'UK & Ireland',
    });

    expect(msg, contains('PATHWAY FOCUS'));
    expect(msg, contains('austerity'));
    expect(msg, contains('stimulus'));
    expect(msg, contains('Sibling pathways'));
    expect(msg, contains('Do not assign equal weight'));
  });
}