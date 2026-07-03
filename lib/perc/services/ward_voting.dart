import '../models/ward_proposal.dart';

/// User ward proposals — listed for everyone for 10 days; one vote per wallet.
class WardVoting {
  const WardVoting._();

  static const Duration listingPeriod = Duration(days: WardProposal.listingDays);

  static WardProposal createUserProposal({
    required String id,
    required String title,
    required String summary,
    required String wardName,
    required String proposerUsername,
    required DateTime now,
  }) {
    final t = now.toUtc();
    return WardProposal(
      id: id,
      title: title.trim(),
      summary: summary.trim(),
      wardName: wardName.trim(),
      proposerUsername: proposerUsername,
      opensAt: t,
      closesAt: t.add(listingPeriod),
    );
  }

  static List<WardProposal> listedForAll({
    required List<WardProposal> proposals,
    DateTime? now,
  }) {
    final t = (now ?? DateTime.now()).toUtc();
    return proposals.where((p) => p.isOpenAt(t)).toList()
      ..sort((a, b) => b.opensAt.compareTo(a.opensAt));
  }

  static WardBallot? ballotFor({
    required List<WardBallot> ballots,
    required String proposalId,
    required String voterUsername,
  }) {
    for (final b in ballots) {
      if (b.proposalId == proposalId && b.voterUsername == voterUsername) {
        return b;
      }
    }
    return null;
  }

  static Map<WardVoteChoice, int> tallyFor({
    required List<WardBallot> ballots,
    required String proposalId,
  }) {
    final counts = {
      WardVoteChoice.forProposal: 0,
      WardVoteChoice.against: 0,
      WardVoteChoice.abstain: 0,
    };
    for (final b in ballots) {
      if (b.proposalId == proposalId) {
        counts[b.choice] = (counts[b.choice] ?? 0) + 1;
      }
    }
    return counts;
  }
}