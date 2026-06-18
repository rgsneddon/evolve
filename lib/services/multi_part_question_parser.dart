import '../models/scenario_input.dart';

/// Detects and parses multi-part percent-chance questions (x, y, z).
class MultiPartQuestionParser {
  const MultiPartQuestionParser._();

  /// Prefer explicit outcome-part fields; fall back to posed-question text parsing.
  static MultiPartQuestion? resolve(ScenarioInput input) {
    if (!input.multiPartOutcomeEnabled) return null;
    final fromFields = fromExplicitFields(input);
    if (fromFields != null) return fromFields;
    return parse(input.scenarioQuery);
  }

  /// Builds a multi-part query from user-entered pathway fields.
  static MultiPartQuestion? fromExplicitFields(ScenarioInput input) {
    if (!input.multiPartOutcomeEnabled) return null;
    final labels = input.filledOutcomeParts;
    if (labels.length < 2) return null;

    final outcome = input.outcomeContext.trim();
    final parent = input.posedQuestion.trim().isNotEmpty
        ? input.posedQuestion.trim()
        : syntheticQuestionFromFields(input);

    final parts = <MultiPartItem>[
      for (final label in labels)
        MultiPartItem(
          label: label,
          subQuestion: _subQuestion(label, outcome),
        ),
    ];

    return MultiPartQuestion(
      parentQuestion: parent,
      outcomeContext: outcome,
      parts: parts,
    );
  }

  static String syntheticQuestionFromFields(ScenarioInput input) {
    return _syntheticParentQuestion(
      input.filledOutcomeParts,
      outcome: input.outcomeContext.trim(),
    );
  }

  static String _syntheticParentQuestion(
    List<String> labels, {
    required String outcome,
  }) {
    final list = labels.join(', ');
    final toward = outcome.isNotEmpty ? ' $outcome' : '';
    return 'Give the percent chances of each $list$toward?';
  }

  static const _othersMarkers = [
    'and others',
    'and other',
    'and other options',
    'and other pathways',
    'and other outcomes',
    'and the rest',
    'et al',
    'non-exhaustive',
    'non exhaustive',
    'not exhaustive',
  ];

  /// Returns null when the question is a single-outcome query.
  static MultiPartQuestion? parse(String rawQuestion) {
    final question = rawQuestion.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (question.isEmpty) return null;

    final lower = question.toLowerCase();
    if (!_hasMultiPartSignal(lower)) return null;

    final withoutOthers = _stripOthersClause(question);
    final extracted = _extractListAndOutcome(withoutOthers);
    if (extracted == null) return null;

    final items = _splitListItems(extracted.listSegment);
    if (items.length < 2) return null;

    final outcome = extracted.outcomeContext.trim();
    final parts = <MultiPartItem>[
      for (final label in items)
        MultiPartItem(
          label: label,
          subQuestion: _subQuestion(label, outcome),
        ),
    ];

    return MultiPartQuestion(
      parentQuestion: question,
      outcomeContext: outcome,
      parts: parts,
    );
  }

  static bool _hasMultiPartSignal(String lower) {
    if (RegExp(r'\beach\b').hasMatch(lower)) return true;
    if (RegExp(r'\bchances?\s+of\s+each\b').hasMatch(lower)) return true;
    if (RegExp(r'\bpercent(?:age)?\s+chances?\s+of\b').hasMatch(lower)) return true;
    if (RegExp(r'\bprobabilities\s+of\s+each\b').hasMatch(lower)) return true;
    if (RegExp(r'\blikelihoods?\s+of\s+each\b').hasMatch(lower)) return true;
    if (RegExp(r'\b(?:vs|versus)\b').hasMatch(lower) &&
        RegExp(r'[,;]').hasMatch(lower)) {
      return true;
    }
    return false;
  }

  static String _stripOthersClause(String question) {
    var t = question;
    t = t.replaceAll(
      RegExp(r'\s*\([^)]*non[- ]?exhaustive[^)]*\)', caseSensitive: false),
      '',
    );
    for (final marker in _othersMarkers) {
      t = t.replaceAll(
        RegExp('\\s*,?\\s*${RegExp.escape(marker)}\\b', caseSensitive: false),
        '',
      );
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static _Extracted? _extractListAndOutcome(String question) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:give|provide|state|list|show|calculate|estimate|compute|tell me|what are)\s+'
        r'(?:the\s+)?(?:percent(?:age)?\s+)?(?:chances?|probabilities|likelihoods?)\s+'
        r'of\s+(?:each\s+)?(.+?)(?:\s+(?:to|toward|towards|for|leading to|in order to)\s+(.+?))(?:\?|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:percent(?:age)?\s+)?(?:chances?|probabilities|likelihoods?)\s+of\s+(?:each\s+)?(.+?)(?:\s+(?:to|toward|towards|for|leading to|in order to)\s+(.+?))(?:\?|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\beach\s+(.+?)(?:\s+(?:to|toward|towards|for|leading to|in order to)\s+(.+?))(?:\?|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:chances?|probabilities|likelihoods?)\s+of\s+(.+?)(?:\?|$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(question);
      if (match == null) continue;
      var listSegment = match.group(1)?.trim() ?? '';
      var outcome = match.groupCount >= 2 ? (match.group(2)?.trim() ?? '') : '';

      if (outcome.isEmpty) {
        final split = _splitTrailingOutcome(listSegment);
        listSegment = split.listSegment;
        outcome = split.outcomeContext;
      }

      listSegment = _trimListSegment(listSegment);
      if (listSegment.isEmpty) continue;
      return _Extracted(listSegment: listSegment, outcomeContext: outcome);
    }
    return null;
  }

  static _Extracted _splitTrailingOutcome(String segment) {
    final match = RegExp(
      r'^(.+?)\s+(?:to|toward|towards|for|leading to|in order to)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(segment.trim());
    if (match == null) {
      return _Extracted(listSegment: segment, outcomeContext: '');
    }
    return _Extracted(
      listSegment: match.group(1)!.trim(),
      outcomeContext: match.group(2)!.trim(),
    );
  }

  static String _trimListSegment(String segment) {
    var t = segment.trim();
    t = t.replaceFirst(RegExp(r'^each\s+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+to the outcome\s*$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+to outcome\s*$', caseSensitive: false), '');
    return t.trim();
  }

  static List<String> _splitListItems(String segment) {
    final normalized = segment
        .replaceAll(RegExp(r'\s+and/or\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s+or\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s*/\s*'), ', ')
        .replaceAll(RegExp(r'\s*;\s*'), ', ');

    final raw = normalized.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

    final items = <String>[];
    for (final piece in raw) {
      final cleaned = _cleanItemLabel(piece);
      if (cleaned.isEmpty) continue;
      if (items.any((e) => e.toLowerCase() == cleaned.toLowerCase())) continue;
      items.add(cleaned);
    }
    return items;
  }

  static String _cleanItemLabel(String raw) {
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'^[\-\*•]\s*'), '');
    t = t.replaceFirst(RegExp(r'^each\s+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'^(?:a|an|the)\s+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    if (t.length < 2) return '';
    if (RegExp(r'^(?:other|others)\b', caseSensitive: false).hasMatch(t)) {
      return '';
    }
    return t;
  }

  static String _subQuestion(String label, String outcome) {
    if (outcome.isEmpty) {
      return 'What is the percent chance of $label?';
    }
    return 'What is the percent chance of $label $outcome?';
  }
}

class MultiPartQuestion {
  const MultiPartQuestion({
    required this.parentQuestion,
    required this.outcomeContext,
    required this.parts,
  });

  final String parentQuestion;
  final String outcomeContext;
  final List<MultiPartItem> parts;
}

class MultiPartItem {
  const MultiPartItem({
    required this.label,
    required this.subQuestion,
  });

  final String label;
  final String subQuestion;
}

class _Extracted {
  const _Extracted({required this.listSegment, required this.outcomeContext});

  final String listSegment;
  final String outcomeContext;
}