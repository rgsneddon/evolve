import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/narrative_link_reader.dart';

void main() {
  test('fetchNarrativeFromLink populates blank construct fields from narrative', () async {
    const narrative =
        'Glasgow unrest outlook\n\n'
        'Protests in Glasgow may escalate as ministers warn that institutional trust '
        'is fraying. First Minister Alex Reed said "media narratives compress grievance '
        'into disorder risk across the city centre this weekend." Police delayed court '
        'review while a survey showed public trust falling sharply.';
    final provider = EvolveProvider(
      linkReader: _StubNarrativeLinkReader(
        NarrativeLinkContent(
          url: 'https://example.com/glasgow-protests',
          title: 'Glasgow unrest outlook',
          narrative: narrative,
        ),
      ),
    );
    await provider.initialize();

    await provider.fetchNarrativeFromLink('https://example.com/glasgow-protests');

    expect(provider.input.sourceUrl, 'https://example.com/glasgow-protests');
    expect(provider.input.posedQuestion, contains('Glasgow'));
    expect(provider.input.vortexText.toLowerCase(), contains('alex reed'));
    expect(provider.input.shearText.toLowerCase(), anyOf(contains('protest'), contains('grievance')));
    expect(provider.input.resistanceText.toLowerCase(), anyOf(contains('court'), contains('police')));
    expect(provider.input.flowText.toLowerCase(), anyOf(contains('trust'), contains('survey')));
    expect(provider.grokConstrualEnabled, isTrue);
    expect(provider.grokFilledFields, containsAll(ScenarioInput.constructKeys));
  });
}

class _StubNarrativeLinkReader extends NarrativeLinkReader {
  _StubNarrativeLinkReader(this._content);

  final NarrativeLinkContent _content;

  @override
  Future<NarrativeLinkContent> fetch(
    String urlString, {
    String? proxyBaseUrl,
  }) async =>
      _content;

  @override
  Future<NarrativeLinkContent> fetchViaProxy(
    String proxyBaseUrl,
    String urlString,
  ) async =>
      _content;
}