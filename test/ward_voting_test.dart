import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_dapp_spec.dart';
import 'package:evolve/perc/models/ward_proposal.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.login(PercChainConstants.treasuryUsername, 'password123');
  ledger.consumeBlockchainLaunchEvent();
  ledger.register('voter1', 'password123');
  ledger.register('voter2', 'password123');
}

void main() {
  test('featured community ward voting dapp is first in suite', () {
    expect(PercDappSpec.beamSuite.first.kind, PercDappKind.communityWardVoting);
    expect(PercDappSpec.featuredDapp.featured, isTrue);
  });

  test('user proposal lists for everyone for 10 days', () {
    final now = DateTime.utc(2026, 7, 3, 12);
    final ledger = PercLedger.empty();
    _seedLedger(ledger);

    final proposal = ledger.submitWardProposal(
      proposerUsername: 'voter1',
      title: 'New pocket park bench',
      summary: 'Install seating by the ward green.',
      wardName: 'Maple Ward',
      now: now,
    );

    expect(proposal.proposerUsername, 'voter1');
    expect(
      proposal.closesAt.difference(proposal.opensAt),
      const Duration(days: WardProposal.listingDays),
    );
    expect(ledger.openWardProposals(now).length, 1);
    expect(
      ledger.openWardProposals(now.add(const Duration(days: 9))).length,
      1,
    );
    expect(
      ledger.openWardProposals(now.add(const Duration(days: 10))).length,
      0,
    );
  });

  test('one vote per wallet per proposal — no recast', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    final now = DateTime.utc(2026, 7, 3);

    final proposal = ledger.submitWardProposal(
      proposerUsername: 'voter1',
      title: 'Traffic calming',
      summary: 'Add speed cushions on school route.',
      wardName: 'Riverside Ward',
      now: now,
    );

    ledger.castWardVote(
      proposalId: proposal.id,
      voterUsername: 'voter1',
      choice: WardVoteChoice.forProposal,
      comment: 'Safer for children.',
      now: now,
    );

    expect(
      () => ledger.castWardVote(
        proposalId: proposal.id,
        voterUsername: 'voter1',
        choice: WardVoteChoice.against,
        comment: 'Too costly.',
        now: now,
      ),
      throwsStateError,
    );

    ledger.castWardVote(
      proposalId: proposal.id,
      voterUsername: 'voter2',
      choice: WardVoteChoice.against,
      comment: 'Prefer alternative route.',
      now: now,
    );

    final tally = ledger.wardTallyFor(proposal.id);
    expect(tally[WardVoteChoice.forProposal], 1);
    expect(tally[WardVoteChoice.against], 1);
    expect(ledger.wardTotalVotesFor(proposal.id), 2);
    expect(ledger.wardPublicBallotsFor(proposal.id).length, 2);
  });

  test('ward proposals persist in ledger json round-trip', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    final proposal = ledger.submitWardProposal(
      proposerUsername: 'voter1',
      title: 'Library hours',
      summary: 'Open Saturday mornings.',
      wardName: 'Hillcrest Ward',
    );
    ledger.castWardVote(
      proposalId: proposal.id,
      voterUsername: 'voter1',
      choice: WardVoteChoice.abstain,
      comment: 'Need budget detail.',
    );

    final restored = PercLedger.fromJson(ledger.toJson());
    expect(restored.wardProposals.length, 1);
    expect(restored.wardBallots.length, 1);
    expect(restored.openWardProposals().single.id, proposal.id);
  });
}