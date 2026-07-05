import 'construal_realtime.dart';
import 'question_semantics.dart';

/// Mines posed-question text for construct levers when live search is thin.
class QuestionParameterScraper {
  const QuestionParameterScraper._();

  static const _stopWords = {
    'what', 'when', 'where', 'which', 'who', 'whom', 'whose', 'why', 'how',
    'will', 'would', 'could', 'should', 'might', 'may', 'can', 'does', 'did',
    'have', 'has', 'had', 'been', 'being', 'are', 'was', 'were', 'the', 'and',
    'for', 'with', 'from', 'that', 'this', 'your', 'near', 'term', 'short',
    'long', 'please', 'give', 'tell', 'calculate', 'estimate', 'compute',
    'chance', 'percent', 'percentage', 'probability', 'likelihood', 'likely',
    'about', 'into', 'over', 'under', 'after', 'before', 'during', 'within',
    'there', 'their', 'they', 'them', 'then', 'than', 'also', 'very', 'much',
  };

  /// Grounded ω/σ/Iτ/Jμ lines from question semantics and salient tokens.
  static Map<String, String> scrape({
    required String question,
    String topic = '',
    required QuestionSemantics sem,
  }) {
    final subject = sem.subject.trim();
    final anchor = subject.isNotEmpty ? subject : _fallbackAnchor(question);
    final salient = salientPhrases(
      question: question,
      topic: topic,
      subject: subject,
    );
    final focus = salient.isNotEmpty ? salient.take(3).join('; ') : anchor;
    final hints = sem.hintSignals.where(_isQuestionDerivedHint).toList();

    final date = ConstrualRealtime.analysisDateIso();
    return {
      'continuum': _continuumLine(anchor, focus, hints, question, date),
      'vortex': _vortexLine(anchor, focus, hints, question, date),
      'shear': _shearLine(anchor, focus, hints, question, date),
      'resistance': _resistanceLine(anchor, focus, hints, question, date),
      'flow': _flowLine(anchor, focus, hints, question, date),
    };
  }

  static List<String> salientPhrases({
    required String question,
    String topic = '',
    String subject = '',
  }) {
    final merged = [question, topic, subject]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    final tokens = merged
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length > 3 && !_stopWords.contains(w))
        .toList();

    final phrases = <String>[];
    if (subject.trim().length >= 4) phrases.add(subject.trim());

    for (var i = 0; i < tokens.length - 1 && phrases.length < 6; i++) {
      final bigram = '${tokens[i]} ${tokens[i + 1]}';
      if (bigram.length >= 8) phrases.add(bigram);
    }
    for (final token in tokens) {
      if (phrases.length >= 8) break;
      if (!phrases.any((p) => p.toLowerCase().contains(token))) {
        phrases.add(token);
      }
    }
    return phrases.toSet().toList();
  }

  static bool _isQuestionDerivedHint(String label) {
    final lower = label.toLowerCase();
    if (lower.startsWith('regional-scope-')) return false;
    if (lower.startsWith('foreign-geo-')) return false;
    return true;
  }

  static String _fallbackAnchor(String question) {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return 'this scenario';
    final line = trimmed.split(RegExp(r'\n+')).first.trim();
    if (line.length <= 96) return line.replaceAll(RegExp(r'\?\s*$'), '');
    return '${line.substring(0, 93).trimRight()}…';
  }

  static String _continuumLine(
    String anchor,
    String focus,
    List<String> hints,
    String question,
    String analysisDate,
  ) {
    final lower = question.toLowerCase();
    if (_matches(lower, r'\b(unrest|protest|condemn|backlash|crisis)\b') ||
        hints.any((h) => h.contains('disorder') || h.contains('narrative'))) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'ρt (continuum): Regressive momentum in ongoing discourse on $anchor — '
        'elite framing outruns nuance in current coverage ($focus).',
      );
    }
    return ConstrualRealtime.withLead(
      analysisDate,
      'ρt (continuum): Continuum lean on $anchor — progressive and regressive '
      'channels both active in ongoing public discourse ($focus).',
    );
  }

  static String _vortexLine(
    String anchor,
    String focus,
    List<String> hints,
    String question,
    String analysisDate,
  ) {
    final lower = question.toLowerCase();
    if (_matches(lower, r'\b(election|vote|referendum|ballot|campaign|mayor)\b') ||
        hints.any((h) => h.contains('electoral'))) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'ω (vortex): Incumbent and party-machine levers around $anchor — '
        'live establishment briefings and mandate framing compress the ω field ($focus).',
      );
    }
    if (_matches(lower, r'\b(minister|government|official|institution|policy|cabinet)\b') ||
        hints.any((h) => h.contains('institutional'))) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'ω (vortex): Institutional authority levers on $anchor — '
        'ongoing spokesperson lanes and procedural framing steer official narrative ($focus).',
      );
    }
    return ConstrualRealtime.withLead(
      analysisDate,
      'ω (vortex): Authority-circulation levers around $anchor — '
      'live elite briefings and official story arcs set the ω compression field ($focus).',
    );
  }

  static String _shearLine(
    String anchor,
    String focus,
    List<String> hints,
    String question,
    String analysisDate,
  ) {
    final lower = question.toLowerCase();
    if (_matches(lower, r'\b(unrest|protest|riot|disorder|march|rally|strike)\b') ||
        hints.any((h) => h.contains('disorder') || h.contains('collective'))) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'σ (shear): Grievance-layer levers on $anchor — '
        'ongoing street discourse and partisan split sharpen over $focus.',
      );
    }
    if (_matches(lower, r'\b(trust|narrative|believe|condemn|sceptic|skeptic)\b') ||
        hints.any((h) => h.contains('narrative'))) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'σ (shear): Polarized discourse levers on $anchor — '
        'live trust-the-lens vs challenge-the-frame camps split over $focus.',
      );
    }
    return ConstrualRealtime.withLead(
      analysisDate,
      'σ (shear): Partisan shear levers on $anchor — '
      'ongoing bottom-up pressure and top-down dismissal across open channels ($focus).',
    );
  }

  static String _resistanceLine(
    String anchor,
    String focus,
    List<String> hints,
    String question,
    String analysisDate,
  ) {
    final lower = question.toLowerCase();
    if (_matches(lower, r'\b(inflation|economy|recession|gdp|fiscal|budget)\b') ||
        hints.any((h) => h.contains('macro-economic'))) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'Iτ (resistance): Fiscal and regulatory guardrail levers on $anchor — '
        'live stability data and compliance checks dampen rapid escalation ($focus).',
      );
    }
    if (_matches(lower, r'\b(court|legal|regulat|law|investigation|inquiry)\b')) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'Iτ (resistance): Legal and procedural drag levers on $anchor — '
        'ongoing appeals, reviews, and institutional inertia slow movement ($focus).',
      );
    }
    return ConstrualRealtime.withLead(
      analysisDate,
      'Iτ (resistance): Drag levers on $anchor — '
      'current official denials, procedural delay, and compliance friction on $focus.',
    );
  }

  static String _flowLine(
    String anchor,
    String focus,
    List<String> hints,
    String question,
    String analysisDate,
  ) {
    final lower = question.toLowerCase();
    if (_matches(lower, r'\b(trust|narrative|credibility|believe|media)\b') ||
        hints.any((h) => h.contains('narrative'))) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'Jμ (flow): Trust-transport levers on $anchor — '
        'ongoing nuance compression into shareable clips as $focus crosses platforms.',
      );
    }
    if (_matches(lower, r'\b(chance|probability|likelihood|percent|odds)\b') ||
        semFrameIsProbability(lower)) {
      return ConstrualRealtime.withLead(
        analysisDate,
        'Jμ (flow): Probability-talk levers on $anchor — '
        'live expert caveats vs headline certainty thin middle-ground trust ($focus).',
      );
    }
    return ConstrualRealtime.withLead(
      analysisDate,
      'Jμ (flow): Channel-reach levers on $anchor — '
      'current local testimony travels unevenly while establishment statements dominate reach ($focus).',
    );
  }

  static bool semFrameIsProbability(String lower) =>
      RegExp(r'\b(chance|probability|likelihood|how likely)\b').hasMatch(lower);

  static bool _matches(String lower, String pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(lower);
}