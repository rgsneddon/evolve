import '../l10n/localized_output.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'grok_construct_discourse.dart';
import 'grok_field_sanitizer.dart';
import 'party_response_extractor.dart';
import 'question_semantics.dart';
/// Narrative-link construal — grounds ω/σ/Iτ/Jμ in linked article text (SCS mode).
class NarrativeConstructConstrual {
  const NarrativeConstructConstrual._();

  static bool isNarrativeLinked(ScenarioInput input) =>
      input.sourceUrl.trim().isNotEmpty && input.posedQuestion.trim().isNotEmpty;

  /// Short cohesion anchor for Grok / semantics (full narrative stays in [ScenarioInput.posedQuestion]).
  static String construalAnchor(ScenarioInput input) {
    final topic = input.topic.trim();
    if (topic.isNotEmpty) {
      return 'What is the social cohesion trajectory around $topic?';
    }
    final headline = _headline(input.posedQuestion);
    if (headline.length >= 12 && headline.length <= 140) {
      return 'What cohesion dynamics does this narrative imply: $headline';
    }
    return 'What is the social cohesion trajectory implied by this linked narrative?';
  }

  static String narrativeBody(ScenarioInput input) => input.posedQuestion.trim();

  static Map<String, dynamic> grokPayload(
    ScenarioInput input,
    LocaleConfig locale,
    LocalizedOutput output,
  ) {
    final linked = isNarrativeLinked(input);
    return {
      'posedQuestion': linked ? construalAnchor(input) : input.posedQuestion,
      'narrativeText': linked ? narrativeBody(input) : '',
      'regionId': locale.regionId,
      'regionLabel': output.regionName(locale.regionId),
      'topic': input.topic,
      'sourceUrl': input.sourceUrl,
      'vortexText': input.vortexText,
      'shearText': input.shearText,
      'resistanceText': input.resistanceText,
      'flowText': input.flowText,
    };
  }

  static GrokConstrualResult suggest({
    required ScenarioInput input,
    required LocaleConfig locale,
    LocalizedOutput? output,
  }) {
    final narrative = narrativeBody(input);
    if (narrative.isEmpty) {
      return const GrokConstrualResult(provenance: 'narrative-construal');
    }

    final out = output ?? LocalizedOutput.of(locale);
    final region = out.regionName(locale.regionId);
    final anchor = construalAnchor(input);
    final sem = QuestionSemantics.fromText(
      anchor,
      regionId: locale.regionId,
      regionLabel: region,
    );
    final subject = sem.displaySubject;
    final sentences = _sentences(narrative);
    final quotes = const PartyResponseExtractor().extract(narrative);

    String pick(String existing, String construct, String? excerpt) {
      if (existing.trim().isNotEmpty) return existing.trim();
      if (excerpt != null && excerpt.trim().isNotEmpty) {
        return _label(construct, _clamp(excerpt, 380));
      }
      return GrokConstructDiscourse.forConstruct(
        construct: construct,
        subject: subject,
        region: region,
        hintSignals: _narrativeHints(narrative, sem.hintSignals),
        observationalNarrative: null,
      );
    }

    final result = GrokConstrualResult(
      vortexText: pick(
        input.vortexText,
        'vortex',
        _vortexExcerpt(sentences, quotes, subject, region),
      ),
      shearText: pick(
        input.shearText,
        'shear',
        _bestSentence(
          sentences,
          const [
            'protest',
            'unrest',
            'anger',
            'polaris',
            'grievance',
            'backlash',
            'condemn',
            'critic',
            'crowd',
            'march',
            'riot',
            'clash',
            'divided',
            'outrage',
          ],
        ),
      ),
      resistanceText: pick(
        input.resistanceText,
        'resistance',
        _bestSentence(
          sentences,
          const [
            'court',
            'legal',
            'law',
            'blocked',
            'denied',
            'delay',
            'procedure',
            'regulat',
            'inertia',
            'refused',
            'compliance',
            'investigation',
            'inquiry',
            'appeal',
          ],
        ),
      ),
      flowText: pick(
        input.flowText,
        'flow',
        _bestSentence(
          sentences,
          const [
            'trust',
            'survey',
            'poll',
            'data',
            'evidence',
            'percent',
            'rate',
            'nuance',
            'channel',
            'social media',
            'credibility',
            'belief',
            'accept',
          ],
        ),
      ),
      provenance: 'narrative-construal',
    );
    return GrokFieldSanitizer.sanitizeResult(
      raw: result,
      input: input,
      locale: locale,
      output: out,
    );
  }

  static List<String> _narrativeHints(String narrative, List<String> base) {
    final hints = <String>[...base];
    final lower = narrative.toLowerCase();
    if (RegExp(r'\b(said|stated|minister|official|spokesperson|government)\b')
        .hasMatch(lower)) {
      hints.add('institutional');
    }
    if (RegExp(r'\b(protest|unrest|disorder|riot|march)\b').hasMatch(lower)) {
      hints.add('collective action');
    }
    if (RegExp(r'\b(trust|narrative|believe|credibility)\b').hasMatch(lower)) {
      hints.add('narrative-lens compression');
    }
    return hints.toSet().toList();
  }

  static String? _vortexExcerpt(
    List<String> sentences,
    List<ExtractedPartyResponse> quotes,
    String subject,
    String region,
  ) {
    if (quotes.isNotEmpty) {
      final q = quotes.first;
      final party = q.party.trim();
      final excerpt = q.excerpt.trim();
      if (party.isNotEmpty && excerpt.isNotEmpty) {
        return 'ω (vortex): Authority-framing lever via $party — $excerpt';
      }
    }
    return _bestSentence(
      sentences,
      const [
        'said',
        'stated',
        'minister',
        'official',
        'government',
        'spokesperson',
        'announced',
        'condemned',
        'warned',
        'briefed',
        'prime minister',
        'mayor',
        'president',
        'cabinet',
      ],
    );
  }

  static String _headline(String narrative) {
    final line = narrative.split(RegExp(r'\n+')).firstWhere(
          (l) => l.trim().length >= 8,
          orElse: () => narrative,
        );
    return line.trim();
  }

  static List<String> _sentences(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 20)
        .toList();
  }

  static String? _bestSentence(List<String> sentences, List<String> keywords) {
    String? best;
    var bestScore = 0;
    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      var score = 0;
      for (final keyword in keywords) {
        if (lower.contains(keyword)) score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = sentence;
      }
    }
    return bestScore > 0 ? best : null;
  }

  static String _label(String construct, String text) {
    final prefix = switch (construct) {
      'vortex' => 'ω (vortex):',
      'shear' => 'σ (shear):',
      'resistance' => 'Iτ (resistance):',
      'flow' => 'Jμ (flow):',
      _ => '',
    };
    final body = GrokFieldSanitizer.sanitizeField(text.trim());
    if (body.isEmpty) return '';
    if (body.toLowerCase().startsWith(prefix.toLowerCase())) return body;
    return '$prefix $body';
  }

  static String _clamp(String text, int maxLen) {
    final t = text.trim();
    if (t.length <= maxLen) return t;
    final cut = t.substring(0, maxLen - 1).trimRight();
    final lastSpace = cut.lastIndexOf(' ');
    final body = lastSpace > maxLen ~/ 2 ? cut.substring(0, lastSpace) : cut;
    return '$body…';
  }
}