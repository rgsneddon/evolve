/// Prompt + parsing for Grok Chronoflux construct fields (ω/σ/Iτ/Jμ).
class GrokConstructPrompt {
  const GrokConstructPrompt._();

  static const systemMessage = '''
You are Grok assisting Evolve Chronoflux — a hydrodynamic social-science framework.
Your job is to populate blank construct variables from the user's posed scenario question.

Use live search (X posts, public discourse, establishment statements, reputable news/data)
to ground each field in observable reality. Search before you answer when the question
is about current or recent events.

CRITICAL RULES:
- NEVER repeat or paraphrase the full posed question in any field.
- Each field is ONE distinct variable statement (max 400 characters).
- Begin each non-empty field with its symbol label: "ω (vortex):", "σ (shear):", "Iτ (resistance):", or "Jμ (flow):".
- Reference the scenario subject briefly (a short noun phrase), not the entire question sentence.
- No betting odds, poll percentages, or prediction-market figures.
- No generic filler ("it depends", "many factors", "complex situation").
- Use "" for fields the user already filled (non-empty in the payload).
- Return strict JSON only: {"vortexText":"","shearText":"","resistanceText":"","flowText":""}
''';

  static String userMessage(Map<String, dynamic> payload) {
    final question = '${payload['posedQuestion'] ?? ''}'.trim();
    final narrative = '${payload['narrativeText'] ?? ''}'.trim();
    final region = '${payload['regionLabel'] ?? payload['regionId'] ?? 'global'}';
    final topic = '${payload['topic'] ?? ''}'.trim();
    final sourceUrl = '${payload['sourceUrl'] ?? ''}'.trim();

    final narrativeBlock = narrative.isNotEmpty
        ? '''

LINKED NARRATIVE TEXT (ground every field in this article — cite specific actors, quotes, and facts from here):
"$narrative"
'''
        : '';

    return '''
POSED SCENARIO QUESTION (context only — do NOT copy into output fields):
"$question"
$narrativeBlock
Region focus: $region
${topic.isNotEmpty ? 'Topic tag: $topic\n' : ''}${sourceUrl.isNotEmpty ? 'Narrative source: $sourceUrl\n' : ''}
Fill ONLY blank construct fields. Each must be a distinct, weight-bearing variable statement grounded in the linked narrative when provided:

ω (vortexText) — authority circulation: how elites, officials, and establishment media
frame or spin the scenario; named institutions or spokespersons when findable.

σ (shearText) — polarized discourse: live public sentiment, grievance layers, partisan
split, protest rhetoric, or bottom-up anger/fear visible in X and open discussion.

Iτ (resistanceText) — structural pushback: institutional inertia, legal/regulatory
barriers, official denials, procedural delay, or hard constraints blocking the outcome.

Jμ (flowText) — trust transport: how nuance travels or compresses across channels;
consensus vs distrust dynamics; cite hard data (counts, rates, dates) only if directly
pertinent to this question.

Existing user inputs (leave corresponding outputs as ""):
- vortex: ${payload['vortexText'] ?? ''}
- shear: ${payload['shearText'] ?? ''}
- resistance: ${payload['resistanceText'] ?? ''}
- flow: ${payload['flowText'] ?? ''}
''';
  }

  /// Reject fields that mostly echo the posed question.
  static Map<String, String> sanitizeFields(
    Map<String, dynamic> parsed,
    String posedQuestion,
  ) {
    final question = posedQuestion.trim();
    String clean(String key) {
      final raw = '${parsed[key] ?? ''}'.trim();
      if (raw.isEmpty) return '';
      if (question.isNotEmpty && isQuestionEcho(raw, question)) return '';
      return _clamp(raw, 400);
    }

    return {
      'vortexText': clean('vortexText'),
      'shearText': clean('shearText'),
      'resistanceText': clean('resistanceText'),
      'flowText': clean('flowText'),
    };
  }

  static bool isQuestionEcho(String field, String question) {
    final f = field.trim().toLowerCase();
    final q = question.trim().toLowerCase();
    if (q.isEmpty || f.isEmpty) return false;
    if (f.startsWith('posed question:')) return true;
    if (f.contains(q)) return true;

    final qWords = q.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    if (qWords.isEmpty) return false;
    final matched = qWords.where((w) => f.contains(w)).length;
    return matched / qWords.length > 0.65;
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