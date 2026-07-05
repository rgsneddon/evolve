import '../models/fcg_models.dart';

enum FcgVoteOutcome {
  pending,
  noQuorum,
  pass,
  fail,
  tie,
}

/// Live tally and quorum evaluation with abstention-aware decision rules.
///
/// Abstentions count toward participation (quorum) but not toward the
/// support/oppose decision denominator — standard parish council practice.
class FcgQuorumEngine {
  const FcgQuorumEngine();

  static const double defaultQuorumPercent = 50;

  FcgQuorumSnapshot evaluate(
    FcgVotingSession session, {
    double quorumPercent = defaultQuorumPercent,
  }) {
    final tally = session.tally;
    final support = tally[FcgVoteChoice.support] ?? 0;
    final oppose = tally[FcgVoteChoice.oppose] ?? 0;
    final abstain = tally[FcgVoteChoice.abstain] ?? 0;
    final enrolled = session.enrolledCount;
    final votesCast = session.votesCast;
    final openSlots = FcgWardDatabase.slotCount - enrolled;

    final participationRate =
        enrolled > 0 ? (votesCast / enrolled) * 100 : 0.0;
    final quorumThreshold = quorumPercent.clamp(1, 100).toDouble();
    final quorumMet = enrolled > 0 && participationRate >= quorumThreshold;

    final decidingVotes = support + oppose;
    final supportShare =
        decidingVotes > 0 ? (support / decidingVotes) * 100 : 0.0;
    final opposeShare = decidingVotes > 0 ? (oppose / decidingVotes) * 100 : 0.0;

    final outcome = _outcome(
      quorumMet: quorumMet,
      enrolled: enrolled,
      votesCast: votesCast,
      support: support,
      oppose: oppose,
      decidingVotes: decidingVotes,
    );

    return FcgQuorumSnapshot(
      support: support,
      oppose: oppose,
      abstain: abstain,
      enrolled: enrolled,
      votesCast: votesCast,
      openSlots: openSlots,
      participationRate: participationRate,
      quorumThresholdPercent: quorumThreshold,
      quorumMet: quorumMet,
      decidingVotes: decidingVotes,
      supportSharePercent: supportShare,
      opposeSharePercent: opposeShare,
      outcome: outcome,
    );
  }

  FcgVoteOutcome _outcome({
    required bool quorumMet,
    required int enrolled,
    required int votesCast,
    required int support,
    required int oppose,
    required int decidingVotes,
  }) {
    if (enrolled == 0 || votesCast == 0) return FcgVoteOutcome.pending;
    if (!quorumMet) return FcgVoteOutcome.noQuorum;
    if (decidingVotes == 0) return FcgVoteOutcome.tie;
    if (support > oppose) return FcgVoteOutcome.pass;
    if (oppose > support) return FcgVoteOutcome.fail;
    return FcgVoteOutcome.tie;
  }
}

class FcgQuorumSnapshot {
  const FcgQuorumSnapshot({
    required this.support,
    required this.oppose,
    required this.abstain,
    required this.enrolled,
    required this.votesCast,
    required this.openSlots,
    required this.participationRate,
    required this.quorumThresholdPercent,
    required this.quorumMet,
    required this.decidingVotes,
    required this.supportSharePercent,
    required this.opposeSharePercent,
    required this.outcome,
  });

  final int support;
  final int oppose;
  final int abstain;
  final int enrolled;
  final int votesCast;
  final int openSlots;
  final double participationRate;
  final double quorumThresholdPercent;
  final bool quorumMet;
  final int decidingVotes;
  final double supportSharePercent;
  final double opposeSharePercent;
  final FcgVoteOutcome outcome;

  Map<String, dynamic> toJson() => {
        'support': support,
        'oppose': oppose,
        'abstain': abstain,
        'enrolled': enrolled,
        'votesCast': votesCast,
        'openSlots': openSlots,
        'participationRate': participationRate,
        'quorumThresholdPercent': quorumThresholdPercent,
        'quorumMet': quorumMet,
        'decidingVotes': decidingVotes,
        'supportSharePercent': supportSharePercent,
        'opposeSharePercent': opposeSharePercent,
        'outcome': outcome.name,
      };
}