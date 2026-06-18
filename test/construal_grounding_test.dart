import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/construal_grounding.dart';
import 'package:evolve/models/grok_session.dart';
import 'package:evolve/services/question_relevance_filter.dart';

void main() {
  const question =
      'What is the chance of sporadic civil unrest in Glasgow near-term?';
  const subject = 'sporadic civil unrest in Glasgow near-term';

  test('isFullyQuestionGrounded rejects generic lever templates', () {
    expect(
      QuestionRelevanceFilter.isFullyQuestionGrounded(
        'σ (shear): Grievance-layer levers sharpen partisan split in open channels.',
        posedQuestion: question,
        displaySubject: subject,
        rawSubject: subject,
      ),
      isFalse,
    );
  });

  test('isFullyQuestionGrounded accepts subject-anchored lines', () {
    expect(
      QuestionRelevanceFilter.isFullyQuestionGrounded(
        'σ (shear): Grievance-layer levers on Glasgow unrest — '
        'street discourse sharpens over sporadic civil unrest.',
        posedQuestion: question,
        displaySubject: subject,
        rawSubject: subject,
      ),
      isTrue,
    );
  });

  test('ensureResult replaces ungrounded fields with scraped question lines', () {
    const input = ScenarioInput(posedQuestion: question);
    const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');
    const raw = GrokConstrualResult(
      vortexText:
          'ω (vortex): Authority-circulation levers — elite briefings set the field.',
      shearText:
          'σ (shear): Partisan shear levers — bottom-up pressure coexists.',
      resistanceText: 'Iτ (resistance): Drag levers absorb activist pressure.',
      flowText: 'Jμ (flow): Channel-reach levers move nuance unevenly.',
      provenance: 'grok-live',
    );

    final grounded = ConstrualGrounding.ensureResult(
      result: raw,
      input: input,
      locale: locale,
    );

    expect(grounded.vortexText.toLowerCase(), contains('glasgow'));
    expect(grounded.shearText.toLowerCase(), contains('glasgow'));
    expect(grounded.resistanceText.toLowerCase(), contains('glasgow'));
    expect(grounded.flowText.toLowerCase(), contains('glasgow'));
    expect(grounded.vortexText, startsWith('ω (vortex):'));
    expect(grounded.provenance, 'grok-live');
  });
}