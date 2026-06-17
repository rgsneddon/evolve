import '../grok_field_sanitizer.dart';

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
- NEVER wrap the question or subject in quotation marks — no quoted parameters.
- Each field is ONE lever-only variable statement (max 400 characters).
- Begin each non-empty field with its symbol label: "ω (vortex):", "σ (shear):", "Iτ (resistance):", or "Jμ (flow):".
- Detail ONLY the levers entailed by that construct:
  ω = authority-circulation levers (briefings, elite framing, spokesperson lanes);
  σ = polarisation/shear levers (grievance layers, partisan split, street discourse);
  Iτ = resistance/drag levers (regulatory guardrails, procedural delay, official denial);
  Jμ = trust-transport levers (nuance compression, channel reach, credibility flow).
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
Fill ONLY blank construct fields. Each must be a lever-only variable statement (no quoted
question or subject parameters) grounded in the linked narrative when provided:

ω (vortexText) — authority-circulation levers: elite briefings, spokesperson lanes,
establishment framing; named institutions when findable.

σ (shearText) — polarisation/shear levers: grievance layers, partisan split, street
discourse, protest rhetoric visible in X and open discussion.

Iτ (resistanceText) — resistance/drag levers: regulatory guardrails, procedural delay,
official denials, institutional inertia blocking rapid change.

Jμ (flowText) — trust-transport levers: nuance compression, channel reach, credibility
flow across platforms; hard data only when directly pertinent.

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
    String posedQuestion, {
    String displaySubject = '',
    String rawSubject = '',
  }) =>
      GrokFieldSanitizer.sanitizeFieldMap(
        parsed,
        posedQuestion,
        displaySubject: displaySubject,
        rawSubject: rawSubject,
      );

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

}