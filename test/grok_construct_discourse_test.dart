import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/grok_construct_discourse.dart';

void main() {
  const question =
      'What is the chance of sporadic civil unrest in Glasgow near-term?';

  test('discourse lines are construct-specific and do not echo full question', () {
    final vortex = GrokConstructDiscourse.fromQuestion(
      construct: 'vortex',
      posedQuestion: question,
      regionId: 'uk_ireland',
      regionLabel: 'UK & Ireland',
    );
    final shear = GrokConstructDiscourse.fromQuestion(
      construct: 'shear',
      posedQuestion: question,
      regionId: 'uk_ireland',
      regionLabel: 'UK & Ireland',
    );

    expect(vortex, contains('ω (vortex):'));
    expect(shear, contains('σ (shear):'));
    expect(vortex.toLowerCase(), isNot(contains(question.toLowerCase())));
    expect(shear.toLowerCase(), isNot(contains(question.toLowerCase())));
    expect(vortex, isNot(contains('"')));
    expect(shear, isNot(contains('"')));
    expect(vortex.toLowerCase(), contains('lever'));
    expect(shear.toLowerCase(), contains('lever'));
    expect(vortex.toLowerCase(), contains('glasgow'));
    expect(shear.toLowerCase(), contains('glasgow'));
    expect(vortex.toLowerCase(), isNot(contains('uk & ireland')));
    expect(shear.toLowerCase(), isNot(contains('uk & ireland')));
    expect(vortex, isNot(equals(shear)));
  });
}