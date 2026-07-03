import '../models/ward_proposal.dart';

/// Seeds and manages community ward proposals (v2.0 governance layer).
class WardVoting {
  const WardVoting._();

  static List<WardProposal> defaultProposals(DateTime now) {
    final open = now.toUtc();
    return [
      WardProposal(
        id: 'ward-maple-pavement-2026',
        title: 'Footpath resurfacing — Maple Ward',
        summary:
            'Allocate ward reserve to resurface cracked footpaths on Birch Lane and the community centre approach.',
        wardName: 'Maple Ward',
        opensAt: open.subtract(const Duration(days: 14)),
        closesAt: open.add(const Duration(days: 30)),
      ),
      WardProposal(
        id: 'ward-riverside-hours-2026',
        title: 'Extend community centre evening hours',
        summary:
            'Fund two additional evening sessions per week for youth programmes and ward assembly meetings.',
        wardName: 'Riverside Ward',
        opensAt: open.subtract(const Duration(days: 7)),
        closesAt: open.add(const Duration(days: 21)),
      ),
      WardProposal(
        id: 'ward-hillcrest-green-2026',
        title: 'Neighbourhood green space covenant',
        summary:
            'Ratify a ward covenant protecting the Hillcrest pocket park from development for twenty-five years.',
        wardName: 'Hillcrest Ward',
        opensAt: open.subtract(const Duration(days: 3)),
        closesAt: open.add(const Duration(days: 45)),
      ),
    ];
  }

  static void ensureProposals(List<WardProposal> proposals) {
    if (proposals.isNotEmpty) return;
    proposals.addAll(defaultProposals(DateTime.now().toUtc()));
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