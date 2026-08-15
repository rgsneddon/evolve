import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_action_block.dart';
import 'package:evolve/perc/services/perc_voting_epoch_wards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet tab click is a confirmable block', () {
    final chain = PercActionChain();
    final block = chain.recordTabClick('wallet');
    expect(block.kind, PercActionKind.tabClick);
    expect(block.detail, 'wallet');
    expect(block.id, isNotEmpty);
    final confirm = chain.confirm(block.id);
    expect(confirm.status, 'confirmed');
    expect(confirm.block?.id, block.id);
    expect(confirm.isConfirmed, isTrue);
  });

  test('keystroke is a confirmable block', () {
    final chain = PercActionChain();
    final block = chain.recordKeystroke('a');
    expect(block.kind, PercActionKind.keystroke);
    expect(block.detail, 'a');
    final confirm = chain.confirm(block.id);
    expect(confirm.status, 'confirmed');
    expect(confirm.block?.detail, 'a');
  });

  test('voting epoch maps into wards', () {
    final wards = PercVotingEpochWards.wardsForEpoch('epoch-2026-08-w1');
    expect(wards, isNotEmpty);
    expect(wards.length, PercVotingEpochWards.wardsPerEpoch);
    expect(wards.first.epochId, 'epoch-2026-08-w1');
    expect(wards.first.wardId, contains('ward-epoch-2026-08-w1-1'));
    expect(wards.map((w) => w.wardIndex).toSet().length, wards.length);
  });

  test('treasury mint is exactly one third of the prior rate', () {
    final prior = PercChainConstants.treasuryMintPriorPerCooldown.microUnits;
    final now = PercChainConstants.treasuryEmissionPerCooldown.microUnits;
    expect(PercChainConstants.treasuryMintKeepNumerator, 1);
    expect(PercChainConstants.treasuryMintKeepDenominator, 3);
    expect(now, prior ~/ 3);
    expect(now * PercChainConstants.treasuryMintKeepDenominator, prior - (prior % 3));
    expect(
      PercChainConstants.emissionForElapsedSeconds(
        PercChainConstants.faucetCooldown.inSeconds,
      ).microUnits,
      now,
    );
  });
}
