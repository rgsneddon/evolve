import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_seed_block.dart';

void main() {
  test('chain height is zero on fresh genesis ledger', () {
    final ledger = PercLedger.empty();
    expect(PercSeedBlock.chainHeightFromBlockCount(ledger.blockHeight), 0);
  });

  test('chain height tracks blocks.length as blocks append', () {
    final ledger = PercLedger.empty();
    ledger.launchBlockchain();
    ledger.blocks.add(
      PercBlock(
        index: 0,
        timestamp: DateTime.utc(2026, 1, 1),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
      ),
    );
    expect(PercSeedBlock.chainHeightFromBlockCount(ledger.blockHeight), 1);
  });

  test('treasury milestone stays at 1 below 100M PERC emission', () {
    expect(
      PercSeedBlock.treasuryEmissionMilestone(PercAmount.zero),
      1,
    );
    expect(
      PercSeedBlock.treasuryEmissionMilestone(
        PercAmount.fromPerc(
          (PercChainConstants.percPerSeedBlock - 1).toDouble(),
        ),
      ),
      1,
    );
  });

  test('treasury milestone advances at each 100M PERC emission threshold', () {
    final perBlock = PercChainConstants.percPerSeedBlock.toDouble();
    expect(
      PercSeedBlock.treasuryEmissionMilestone(PercAmount.fromPerc(perBlock)),
      2,
    );
    expect(
      PercSeedBlock.treasuryEmissionMilestone(PercAmount.fromPerc(perBlock * 2)),
      3,
    );
  });
}