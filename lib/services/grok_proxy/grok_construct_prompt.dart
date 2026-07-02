import '../grok_field_sanitizer.dart';

/// Prompt + parsing for Grok Chronoflux construct fields (ω/σ/Iτ/Jμ).
class GrokConstructPrompt {
  const GrokConstructPrompt._();

  static const systemMessage = '''
You are Grok assisting Evolve Chronoflux — a hydrodynamic social-science framework.
Your job is to populate blank construct variables from the user's posed scenario question.

DISCOURSE AUDIT (complete before returning JSON):
1. Run live search (X posts, public discourse, establishment statements, reputable news/data)
   for material DIRECTLY bearing on the posed scenario — even when a linked narrative is provided.
2. Cross-check at least two discourse lanes per construct (e.g. establishment briefings vs street
   grievance, official denial vs activist pressure, expert caveat vs headline certainty).
3. Each ω/σ/Iτ/Jμ field must cite concrete actors, institutions, events, dates, or statistics
   found in search or the linked narrative — never generic templates or equal-weight filler.
4. If one source is thin, widen search across X, news wires, and official statements before
   inferring; infer only when search is exhausted and name what is inferred.
5. For multi-part pathways, audit ONLY the active pathway; do not reuse sibling pathway discourse.

Use live search only when results DIRECTLY bear on the POSED SCENARIO QUESTION. Search before you
answer when the question is about current or recent events — but discard tangential hits.

CRITICAL RULES:
- Every cited fact, statistic, actor, date, or event must be WHOLLY RELEVANT to the
  posed scenario question — no tangential news, unrelated regions, or off-topic discourse.
- If search returns material not about the question subject, ignore it — do not cite.
- NEVER repeat or paraphrase the full posed question in any field.
- NEVER wrap the question or subject in quotation marks — no quoted parameters.
- Do NOT name the region in field text — region is already selected in the app UI.
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
- You MUST return non-empty lever lines for every blank field — search broadly (X, news,
  official statements, data) until each construct has question-grounded parameters from
  verified social discourse or data narratives.
- If search is thin, infer levers from the posed question subject, actors, and timeframe —
  but only after exhausting relevant search; state the inference clearly in the lever line.
- Each non-empty field MUST name or cite at least one salient token from the posed question
  (subject, actor, place, event, or topic tag) — generic lever templates without question
  overlap are invalid and must be rewritten.
- Return strict JSON only: {"vortexText":"","shearText":"","resistanceText":"","flowText":""}
''';

  static String userMessage(Map<String, dynamic> payload) {
    final question = '${payload['posedQuestion'] ?? ''}'.trim();
    final narrative = '${payload['narrativeText'] ?? ''}'.trim();
    final region = '${payload['regionLabel'] ?? payload['regionId'] ?? 'global'}';
    final topic = '${payload['topic'] ?? ''}'.trim();
    final sourceUrl = '${payload['sourceUrl'] ?? ''}'.trim();
    final pathwayLabel = '${payload['pathwayLabel'] ?? ''}'.trim();
    final outcomeContext = '${payload['outcomeContext'] ?? ''}'.trim();
    final parentQuestion = '${payload['parentPosedQuestion'] ?? ''}'.trim();
    final multiPartPathway = payload['multiPartPathway'] == true;
    final siblings = (payload['siblingPathwayLabels'] as List<dynamic>? ?? const [])
        .map((s) => '$s'.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final xUser = '${payload['xScreenName'] ?? ''}'.trim();
    final xAccountBlock = xUser.isNotEmpty
        ? '''

SIGNED-IN X ACCOUNT: @$xUser
Observe live social discourse on X as this authenticated Premium user would —
prioritise posts, replies, and threads from their timeline ecosystem and verified
public discourse lanes relevant to the scenario.
'''
        : '';

    final pathwayBlock = multiPartPathway && pathwayLabel.isNotEmpty
        ? '''

PATHWAY FOCUS — deep construct analysis for THIS pathway only (not siblings):
Pathway: $pathwayLabel
${outcomeContext.isNotEmpty ? 'Shared outcome: $outcomeContext\n' : ''}${parentQuestion.isNotEmpty ? 'Parent question: $parentQuestion\n' : ''}${siblings.isNotEmpty ? 'Sibling pathways (contrast only — do NOT populate their levers): ${siblings.join(', ')}\n' : ''}
Search and scrape discourse, news, and data specific to "$pathwayLabel" leading to the shared outcome.
Each ω/σ/Iτ/Jμ field must name levers, actors, and discourse lanes UNIQUE to this pathway — not generic
shared-outcome filler. Contrast implicitly against siblings: where "$pathwayLabel" differs in authority
circulation, polarisation, drag, or trust transport versus ${siblings.isEmpty ? 'other routes' : siblings.join(', ')}.
Do not assign equal weight or identical lever templates across pathways.
'''
        : '';

    final narrativeBlock = narrative.isNotEmpty
        ? '''

LINKED NARRATIVE TEXT (ground every field in this article — cite specific actors, quotes, and facts from here):
"$narrative"
'''
        : '';

    return '''
POSED SCENARIO QUESTION (context only — do NOT copy into output fields):
"$question"
$xAccountBlock
$pathwayBlock
$narrativeBlock
Region focus: $region
${topic.isNotEmpty ? 'Topic tag: $topic\n' : ''}${sourceUrl.isNotEmpty ? 'Narrative source: $sourceUrl\n' : ''}
DISCOURSE AUDIT CHECKLIST — complete before filling fields:
- Search X and open discourse for question-relevant posts, grievance narratives, and partisan split.
- Check news and data for actors, dates, institutions, and statistics tied to the subject.
- Check establishment/official statements for authority-circulation (ω) and drag (Iτ) levers.
- Map polarisation channels (σ) and trust-transport reach (Jμ) across platforms and briefings.
- Every non-empty field must name at least one salient question token AND one discourse finding.

Fill ONLY blank construct fields — all four must be non-empty when blank in the payload.
Each must be a lever-only variable statement (no quoted question or subject parameters;
no "in [region]" phrasing) grounded in question-relevant evidence from search and the
linked narrative when provided. Every field must cite the question subject or a salient
parameter (actor, place, institution, event) — never generic filler levers. Scrape every
available parameter (actors, dates, institutions, events, statistics) that bears on
the posed question:

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
    String regionLabel = '',
    String topic = '',
  }) =>
      GrokFieldSanitizer.sanitizeFieldMap(
        parsed,
        posedQuestion,
        displaySubject: displaySubject,
        rawSubject: rawSubject,
        regionLabel: regionLabel,
        topic: topic,
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