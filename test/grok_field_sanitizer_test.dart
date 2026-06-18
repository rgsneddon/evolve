import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/grok_field_sanitizer.dart';

void main() {
  const question =
      'What is the chance of sporadic civil unrest in Glasgow near-term?';
  const subject = 'sporadic civil unrest in Glasgow near-term';

  test('strips straight and curly quoted question parameters', () {
    final cleaned = GrokFieldSanitizer.sanitizeField(
      'σ (shear): Polarisation on Glasgow unrest sharpens grievance layers.',
      posedQuestion: question,
      displaySubject: subject,
    );

    expect(cleaned, isNot(contains('"')));
    expect(cleaned, contains('σ (shear)'));
    expect(cleaned.toLowerCase(), isNot(contains(subject.toLowerCase())));
  });

  test('strips Unicode curly quotes from live Grok-style output', () {
    final raw =
        'ω (vortex): Glasgow elite briefings on \u201Cnear-term escalation\u201D compress authority lanes.';
    final cleaned = GrokFieldSanitizer.sanitizeField(
      raw,
      posedQuestion: question,
      displaySubject: subject,
    );

    expect(cleaned, isNot(contains('\u201C')));
    expect(cleaned, isNot(contains('\u201D')));
    expect(cleaned, startsWith('ω (vortex)'));
  });

  test('strips in-region phrasing from live Grok-style output', () {
    final cleaned = GrokFieldSanitizer.sanitizeField(
      'σ (shear): Grievance levers in UK & Ireland sharpen partisan split.',
      regionLabel: 'UK & Ireland',
    );

    expect(cleaned.toLowerCase(), isNot(contains('uk & ireland')));
    expect(cleaned, contains('σ (shear)'));
  });

  test('sanitizeFieldMap removes echoed posed question payloads', () {
    final cleaned = GrokFieldSanitizer.sanitizeFieldMap(
      {
        'vortexText': 'Posed question: "$question"',
        'shearText':
            'σ (shear): Grievance-layer levers on Glasgow unrest sharpen partisan split.',
        'resistanceText': '',
        'flowText': '',
      },
      question,
      displaySubject: subject,
    );

    expect(cleaned['vortexText'], isEmpty);
    expect(cleaned['shearText'], contains('σ (shear)'));
    expect(cleaned['shearText'], isNot(contains('"')));
  });
}