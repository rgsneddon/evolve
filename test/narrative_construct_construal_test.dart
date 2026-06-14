import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/narrative_construct_construal.dart';

void main() {
  test('narrative construal extracts party-quote vortex from linked article', () {
    const narrative = '''
Glasgow unrest outlook

Minister warned that protests may escalate across the city centre this weekend.
First Minister John Smith said "institutional trust is fraying and media narratives compress grievance into disorder risk".
Police delayed court proceedings while survey data showed trust falling to 41 percent.
''';

    final input = ScenarioInput(
      sourceUrl: 'https://example.com/glasgow',
      topic: 'Glasgow unrest outlook',
      posedQuestion: narrative,
    );

    final result = NarrativeConstructConstrual.suggest(
      input: input,
      locale: LocaleConfig.defaults,
    );

    expect(result.vortexText.toLowerCase(), contains('john smith'));
    expect(result.shearText.toLowerCase(), anyOf(contains('protest'), contains('unrest')));
    expect(result.flowText.toLowerCase(), anyOf(contains('trust'), contains('survey')));
    expect(result.vortexText, startsWith('ω (vortex):'));
    expect(result.shearText, startsWith('σ (shear):'));
  });

  test('grok payload uses cohesion anchor and full narrative body', () {
    const input = ScenarioInput(
      sourceUrl: 'https://example.com/story',
      topic: 'Mayor race tensions',
      posedQuestion: 'Long narrative body about mayor race tensions in the capital city.',
    );

    final payload = NarrativeConstructConstrual.grokPayload(
      input,
      LocaleConfig.defaults,
      LocalizedOutput.of(LocaleConfig.defaults),
    );

    expect(payload['narrativeText'], contains('mayor race'));
    expect('${payload['posedQuestion']}', contains('social cohesion'));
    expect(payload['posedQuestion'], isNot(equals(input.posedQuestion)));
  });
}