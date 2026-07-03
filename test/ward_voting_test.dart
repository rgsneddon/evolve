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
  ledger.login('voter1', 'password123');
}

void main() {
  test('featured community ward voting dapp is first in suite', () {
    expect(PercDappSpec.beamSuite.first.kind, PercDappKind.communityWardVoting);
    expect(PercDappSpec.featuredDapp.featured, isTrue);
  });

  test('ledger seeds open ward proposals and records ballots', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    final proposals = ledger.openWardProposals();
    expect(proposals, isNotEmpty);

    final id = proposals.first.id;
    final ballot = ledger.castWardVote(
      proposalId: id,
      voterUsername: 'voter1',
      choice: WardVoteChoice.forProposal,
      comment: 'Supports safer footpaths for families.',
    );
    expect(ballot.comment, contains('footpaths'));
    expect(ledger.wardTallyFor(id)[WardVoteChoice.forProposal], 1);

    ledger.castWardVote(
      proposalId: id,
      voterUsername: 'voter1',
      choice: WardVoteChoice.against,
      comment: 'Prefer cycling lanes first.',
    );
    expect(ledger.wardTallyFor(id)[WardVoteChoice.forProposal], 0);
    expect(ledger.wardTallyFor(id)[WardVoteChoice.against], 1);
  });

  test('ward proposals persist in ledger json round-trip', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    final id = ledger.openWardProposals().first.id;
    ledger.castWardVote(
      proposalId: id,
      voterUsername: 'voter1',
      choice: WardVoteChoice.abstain,
      comment: 'Need more data.',
    );

    final restored = PercLedger.fromJson(ledger.toJson());
    expect(restored.wardBallots.length, 1);
    expect(restored.openWardProposals().length, greaterThanOrEqualTo(1));
  });
}