import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/multi_part_question_parser.dart';

void main() {
  test('parses each-list with outcome clause — strips others from list', () {
    const question =
        'Give the percent chances of each austerity, stimulus, and status quo '
        'and others (non-exhaustive) to end the recession?';

    final parsed = MultiPartQuestionParser.parse(question);
    expect(parsed, isNotNull);
    expect(parsed!.parts.length, 3);
    expect(parsed.parts[0].label, 'austerity');
    expect(parsed.parts[1].label, 'stimulus');
    expect(parsed.parts[2].label, 'status quo');
    expect(parsed.outcomeContext.toLowerCase(), contains('end the recession'));
    expect(
      parsed.parts[0].subQuestion.toLowerCase(),
      contains('austerity'),
    );
  });

  test('parses comma-separated pathways without others', () {
    const question =
        'What are the chances of each hard landing, soft landing, and no recession?';

    final parsed = MultiPartQuestionParser.parse(question);
    expect(parsed, isNotNull);
    expect(parsed!.parts.length, 3);
    expect(parsed.parts.map((p) => p.label), [
      'hard landing',
      'soft landing',
      'no recession',
    ]);
  });

  test('returns null for single-outcome questions', () {
    expect(
      MultiPartQuestionParser.parse(
        'What is the chance of civil unrest in Glasgow near-term?',
      ),
      isNull,
    );
  });

  test('parses percent chances of each with toward outcome', () {
    const question =
        'Percent chances of each remain, leave, and renegotiate toward Brexit resolution?';

    final parsed = MultiPartQuestionParser.parse(question);
    expect(parsed, isNotNull);
    expect(parsed!.parts.length, 3);
    expect(parsed.outcomeContext.toLowerCase(), contains('brexit'));
  });
}