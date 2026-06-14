/// Individual party-response SCS from a linked narrative.
class PartyResponseScore {
  const PartyResponseScore({
    required this.party,
    required this.role,
    required this.excerpt,
    required this.scs,
    required this.progressivePct,
    required this.regressivePct,
    required this.lean,
  });

  final String party;
  final String role;
  final String excerpt;
  final double scs;
  final double progressivePct;
  final double regressivePct;
  final String lean;
}

/// Refines narrative SCS using per-party response scores from a linked article.
class NarrativePartyRefinement {
  const NarrativePartyRefinement({
    required this.responses,
    required this.narrativeScsBefore,
    required this.refinedNarrativeScs,
    required this.relianceWeight,
    required this.summary,
  });

  final List<PartyResponseScore> responses;
  final double narrativeScsBefore;
  final double refinedNarrativeScs;
  final double relianceWeight;
  final String summary;

  bool get applied => responses.isNotEmpty && relianceWeight > 0;
}