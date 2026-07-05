/// Keeps Grok-construe field text and cited data aligned with the posed question only.
class QuestionRelevanceFilter {
  const QuestionRelevanceFilter._();

  static const _geographyTokens = {
    'paris', 'london', 'berlin', 'madrid', 'rome', 'tokyo', 'beijing', 'moscow',
    'kyiv', 'kiev', 'warsaw', 'dublin', 'brussels', 'vienna', 'oslo', 'stockholm',
    'copenhagen', 'helsinki', 'lisbon', 'athens', 'prague', 'budapest', 'bucharest',
    'ankara', 'tehran', 'baghdad', 'cairo', 'nairobi', 'lagos', 'mumbai', 'delhi',
    'sydney', 'melbourne', 'toronto', 'montreal', 'vancouver', 'chicago', 'boston',
    'houston', 'miami', 'seattle', 'denver', 'phoenix', 'atlanta', 'detroit',
  };

  static const _stopWords = {
    'what', 'when', 'where', 'which', 'who', 'whom', 'whose', 'why', 'how',
    'will', 'would', 'could', 'should', 'might', 'may', 'can', 'does', 'did',
    'have', 'has', 'had', 'been', 'being', 'are', 'was', 'were', 'the', 'and',
    'for', 'with', 'from', 'that', 'this', 'your', 'near', 'term', 'short',
    'long', 'please', 'give', 'tell', 'calculate', 'estimate', 'compute',
    'chance', 'percent', 'percentage', 'probability', 'likelihood', 'likely',
    'about', 'into', 'over', 'under', 'after', 'before', 'during', 'within',
  };

  static Set<String> questionTokens({
    required String posedQuestion,
    String displaySubject = '',
    String rawSubject = '',
    String topic = '',
  }) {
    final merged = [
      posedQuestion,
      displaySubject,
      rawSubject,
      topic,
    ].where((s) => s.trim().isNotEmpty).join(' ');
    return _tokens(merged);
  }

  /// True when field text cites the posed question subject or salient tokens.
  static bool isFullyQuestionGrounded(
    String field, {
    required String posedQuestion,
    String displaySubject = '',
    String rawSubject = '',
    String topic = '',
  }) {
    final t = field.trim();
    if (t.isEmpty || posedQuestion.trim().isEmpty) return false;

    final qTokens = questionTokens(
      posedQuestion: posedQuestion,
      displaySubject: displaySubject,
      rawSubject: rawSubject,
      topic: topic,
    );
    if (qTokens.isEmpty) return true;
    if (_hasOffTopicGeography(t, qTokens)) return false;
    if (relevanceScore(t, qTokens: qTokens) > 0) return true;
    if (_matchesSubjectFragment(t, displaySubject)) return true;
    if (_matchesSubjectFragment(t, rawSubject)) return true;
    return _matchesSubjectFragment(t, topic);
  }

  static bool _matchesSubjectFragment(String text, String subject) {
    final s = subject.trim();
    if (s.isEmpty) return false;
    final lower = text.toLowerCase();
    for (final token in _tokens(s)) {
      if (token.length > 3 && lower.contains(token)) return true;
    }
    return false;
  }

  /// Lenient filter for Grok-construe fields — drops only clearly off-topic sentences.
  static String enforceConstrualRelevance(
    String field, {
    required String posedQuestion,
    String displaySubject = '',
    String rawSubject = '',
  }) {
    final t = field.trim();
    if (t.isEmpty || posedQuestion.trim().isEmpty) return t;

    final qTokens = questionTokens(
      posedQuestion: posedQuestion,
      displaySubject: displaySubject,
      rawSubject: rawSubject,
    );
    if (qTokens.isEmpty) return t;

    final sentences = _splitSentences(t);
    if (sentences.isEmpty) {
      return _construalSentenceRelevant(
        t,
        qTokens,
        displaySubject: displaySubject,
        rawSubject: rawSubject,
      )
          ? t
          : '';
    }

    if (sentences.length == 1) {
      final only = sentences.first;
      return _construalSentenceRelevant(
        only,
        qTokens,
        displaySubject: displaySubject,
        rawSubject: rawSubject,
      )
          ? only
          : '';
    }

    final kept = sentences
        .where(
          (s) => _construalSentenceRelevant(
            s,
            qTokens,
            displaySubject: displaySubject,
            rawSubject: rawSubject,
          ),
        )
        .toList();
    return kept.join(' ').trim();
  }

  static bool _construalSentenceRelevant(
    String sentence,
    Set<String> qTokens, {
    String displaySubject = '',
    String rawSubject = '',
  }) {
    final s = sentence.trim();
    if (s.isEmpty) return false;
    if (_hasOffTopicGeography(s, qTokens)) return false;
    if (relevanceScore(s, qTokens: qTokens) > 0) return true;
    if (_matchesSubjectFragment(s, displaySubject)) return true;
    if (_matchesSubjectFragment(s, rawSubject)) return true;
    return false;
  }

  static String enforceFieldRelevance(
    String field, {
    required String posedQuestion,
    String displaySubject = '',
    String rawSubject = '',
  }) {
    final t = field.trim();
    if (t.isEmpty || posedQuestion.trim().isEmpty) return t;

    final qTokens = questionTokens(
      posedQuestion: posedQuestion,
      displaySubject: displaySubject,
      rawSubject: rawSubject,
    );
    if (qTokens.isEmpty) return t;

    final sentences = _splitSentences(t);
    if (sentences.isEmpty) {
      return _sentenceRelevant(t, qTokens) ? t : '';
    }

    if (sentences.length == 1) {
      final only = sentences.first;
      return _sentenceRelevant(only, qTokens) ? only : '';
    }

    final kept = sentences.where((s) => _sentenceRelevant(s, qTokens)).toList();
    if (kept.isEmpty) return '';
    return kept.join(' ').trim();
  }

  static int relevanceScore(
    String text, {
    required Set<String> qTokens,
  }) {
    if (text.trim().isEmpty || qTokens.isEmpty) return 0;
    final fieldTokens = _tokens(text);
    if (fieldTokens.isEmpty) return 0;
    return fieldTokens.where(qTokens.contains).length;
  }

  static Set<String> _tokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length > 3 && !_stopWords.contains(w))
        .toSet();
  }

  static bool _sentenceRelevant(String sentence, Set<String> qTokens) {
    final s = sentence.trim();
    if (s.isEmpty) return false;

    final overlap = relevanceScore(s, qTokens: qTokens);
    if (overlap > 0) return true;

    if (!containsExternalData(s) && _isConstructLeverLine(s)) {
      return !_hasOffTopicGeography(s, qTokens);
    }
    if (!containsExternalData(s) && _isLeverOnlyTemplate(s)) return true;

    return false;
  }

  static bool _hasOffTopicGeography(String text, Set<String> qTokens) {
    for (final token in _tokens(text)) {
      if (_geographyTokens.contains(token) && !qTokens.contains(token)) {
        return true;
      }
    }
    return false;
  }

  static bool _isConstructLeverLine(String text) =>
      RegExp(r'^(?:ρt|ω|σ|Iτ|Jμ)\s*\([^)]+\):', caseSensitive: false)
          .hasMatch(text.trim());

  // Public alias for sanitizer fallback checks.
  static bool isConstructLeverLine(String text) => _isConstructLeverLine(text);

  static bool _isLeverOnlyTemplate(String text) {
    final lower = text.toLowerCase();
    return RegExp(r'^[ωσjμιτ]\s*\(').hasMatch(lower) ||
        lower.contains('lever') ||
        lower.contains('grievance-layer') ||
        lower.contains('guardrail') ||
        lower.contains('trust-transport') ||
        lower.contains('authority-circulation') ||
        lower.contains('procedural delay') ||
        lower.contains('channel-reach');
  }

  static bool containsExternalData(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (RegExp(r'\d').hasMatch(t)) return true;
    if (RegExp(r'@\w+').hasMatch(t)) return true;
    if (RegExp(r'\b(?:january|february|march|april|may|june|july|august|'
            r'september|october|november|december)\b',
        caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
            caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    if (RegExp(r'\b(?:according to|reported|sources say|data show)\b',
            caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    return false;
  }

  static List<String> _splitSentences(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];

    final parts = normalized
        .split(RegExp(r'(?<=[.!?;])\s+|(?<= — )\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.length > 1) return parts;

    final clauses = normalized
        .split(RegExp(r'\s*[,–]\s*'))
        .map((s) => s.trim())
        .where((s) => s.length >= 12)
        .toList();
    return clauses.length > 1 ? clauses : [normalized];
  }

  /// Hint labels shown as construal data points — question text only, not UI region scope.
  static List<String> questionDerivedHints(List<String> hints) =>
      hints.where(_isQuestionDerivedHint).toList(growable: false);

  static bool _isQuestionDerivedHint(String label) {
    final lower = label.toLowerCase();
    if (lower.startsWith('regional-scope-')) return false;
    if (lower.startsWith('foreign-geo-')) return false;
    return true;
  }
}