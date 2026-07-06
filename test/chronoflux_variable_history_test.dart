import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/chronoflux_variable_history.dart';

void main() {
  test('history extracts five construct scores from scenario reward txs', () {
    final now = DateTime.utc(2026, 7, 3, 12);
    final blocks = [
      PercBlock(
        index: 0,
        timestamp: now,
        treasuryEmitted: PercAmount.zero,
        transactions: [
          PercTransaction(
            id: 'tx1',
            kind: PercTxKind.scenarioReward,
            amount: PercAmount.fromPerc(0.42),
            timestamp: now,
            percentChance: 42,
            continuumScs: 42,
            vortexScs: 55,
            shearScs: 48,
            resistanceScs: 51,
            flowScs: 60,
          ),
        ],
      ),
    ];

    final history = ChronofluxVariableHistory.fromBlocks(blocks);
    expect(history.length, 1);
    expect(history.first.vortexScs, 55);
    expect(history.first.shearScs, 48);
    expect(ChronofluxVariableHistory.seriesForKey(history, 'vortex'), [55]);
  });

  test('legacy txs infer five points from percent outcome', () {
    final tx = PercTransaction(
      id: 'legacy',
      kind: PercTxKind.scenarioReward,
      amount: PercAmount.fromPerc(0.25),
      timestamp: DateTime.utc(2026, 1, 1),
      percentChance: 25,
    );
    final snap = ChronofluxVariableHistory.snapshotFromTransaction(tx);
    expect(snap, isNotNull);
    expect(snap!.continuumScs, 25);
    expect(snap.vortexScs, 25);
  });
}