/// Attributed party response extracted from a linked narrative.
class ExtractedPartyResponse {
  const ExtractedPartyResponse({required this.party, required this.excerpt});

  final String party;
  final String excerpt;
}

/// Pulls quoted / attributed party statements from narrative link text.
class PartyResponseExtractor {
  const PartyResponseExtractor();

  static final _attributionVerbs = RegExp(
    r'\b(said|stated|told|responded|condemned|announced|wrote|added|declared|urged|insisted|argued|claimed|warned|replied|commented)\b',
    caseSensitive: false,
  );

  static final _partyName = r'(?:[A-Z][A-Za-z\u2019\x27.-]+(?:\s+|-)?){1,6}';

  static final _verbs =
      r'(?:said|stated|told|responded|condemned|announced|wrote|added|declared|urged|insisted|argued|claimed|warned|replied|commented)';

  static final _openQuote = r'["\u201C]';
  static final _closeQuote = r'["\u201D]';
  static final _quotedText = r'[^"\u201C\u201D]{12,}?';

  static final _extractPatterns = <_PatternSpec>[
    _PatternSpec(
      RegExp(
        '($_partyName)\\s+$_verbs\\s*[,:]?\\s*$_openQuote($_quotedText)$_closeQuote',
        caseSensitive: false,
      ),
      _PatternKind.partyThenQuote,
    ),
    _PatternSpec(
      RegExp(
        '$_openQuote($_quotedText)$_closeQuote\\s*,?\\s*(?:said|according to|stated|according)\\s+($_partyName)',
        caseSensitive: false,
      ),
      _PatternKind.quoteThenParty,
    ),
    _PatternSpec(
      RegExp(
        '($_partyName)\\s*[:\\-\u2014]\\s*$_openQuote($_quotedText)$_closeQuote',
        caseSensitive: false,
      ),
      _PatternKind.partyThenQuote,
    ),
    _PatternSpec(
      RegExp(
        r'\b(First Minister|Prime Minister|Mayor|Minister|President|spokesperson|spokesman|spokeswoman|Governor|Chancellor|Secretary)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+'
        r'(?:said|stated|condemned|announced|responded|urged|warned)\s*(?:that\s+)?(.{18,280})',
        caseSensitive: false,
      ),
      _PatternKind.titleNameThenText,
    ),
  ];

  bool narrativeReliesOnPartyResponses(String narrative) {
    final text = narrative.trim();
    if (text.length < 40) return false;
    if (_attributionVerbs.hasMatch(text)) return true;
    if (RegExp(r'["\u201C][^"\u201C\u201D]{12,}["\u201D]').hasMatch(text)) {
      return true;
    }
    return RegExp(
      r'\b(First Minister|Prime Minister|Mayor|Minister|President|spokesperson|official|government)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  List<ExtractedPartyResponse> extract(String narrative) {
    final text = narrative.replaceAll(RegExp(r'\s+'), ' ').trim();
    final found = <ExtractedPartyResponse>[];
    final seen = <String>{};

    for (final spec in _extractPatterns) {
      for (final match in spec.pattern.allMatches(text)) {
        late String party;
        late String excerpt;
        switch (spec.kind) {
          case _PatternKind.partyThenQuote:
            party = match.group(1)!.trim();
            excerpt = match.group(2)!.trim();
          case _PatternKind.quoteThenParty:
            excerpt = match.group(1)!.trim();
            party = match.group(2)!.trim();
          case _PatternKind.titleNameThenText:
            party = '${match.group(1)!.trim()} ${match.group(2)!.trim()}';
            excerpt = match.group(3)!.trim();
        }

        party = _cleanParty(party);
        excerpt = _cleanExcerpt(excerpt);
        if (party.length < 3 || excerpt.length < 12) continue;

        final key =
            '${party.toLowerCase()}::${excerpt.substring(0, excerpt.length.clamp(0, 40))}';
        if (seen.contains(key)) continue;
        seen.add(key);
        found.add(ExtractedPartyResponse(party: party, excerpt: excerpt));
        if (found.length >= 6) return found;
      }
    }

    return found;
  }

  String _cleanParty(String party) =>
      party
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^the\s+', caseSensitive: false), '')
          .trim();

  String _cleanExcerpt(String excerpt) {
    var t = excerpt.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(RegExp(r'^[,:\-\u2014\s]+'), '');
    t = t.replaceAll(RegExp(r'^["\u201C]+'), '');
    t = t.replaceAll(RegExp(r'["\u201D]+$'), '');
    if (t.length > 280) t = '${t.substring(0, 277)}…';
    return t;
  }
}

enum _PatternKind { partyThenQuote, quoteThenParty, titleNameThenText }

class _PatternSpec {
  const _PatternSpec(this.pattern, this.kind);

  final RegExp pattern;
  final _PatternKind kind;
}