import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tip hash ignores scenario narrative fields', () {
    final longLabel =
        'Percent chance: ${'x' * 300}';
    final truncatedLabel = 'Percent chance: ${'x' * 80}…';

    PercLedger ledgerWithFull(PercBlock block) {
      return PercLedger(
        accounts: {},
        blocks: [block],
        lastScenarioAt: DateTime.utc(2026, 7, 5, 12),
        treasuryGenesisDone: true,
        cumulativeTreasuryMinted: PercAmount.zero,
      );
    }

    final fullBlock = PercBlock(
      index: 0,
      timestamp: DateTime.utc(2026, 7, 5, 12),
      treasuryEmitted: PercAmount.zero,
      scenarioLabel: longLabel,
      transactions: [
        PercTransaction(
          id: 'tx-1',
          kind: PercTxKind.scenarioReward,
          amount: PercAmount.fromPerc(1),
          timestamp: DateTime.utc(2026, 7, 5, 12),
          scenarioLabel: longLabel,
          memo: 'memo with narrative',
          percentChance: 42,
        ),
      ],
    );

    final truncatedBlock = PercBlock(
      index: 0,
      timestamp: DateTime.utc(2026, 7, 5, 12),
      treasuryEmitted: PercAmount.zero,
      scenarioLabel: truncatedLabel,
      transactions: [
        PercTransaction(
          id: 'tx-1',
          kind: PercTxKind.scenarioReward,
          amount: PercAmount.fromPerc(1),
          timestamp: DateTime.utc(2026, 7, 5, 12),
          scenarioLabel: truncatedLabel,
          percentChance: 42,
        ),
      ],
    );

    expect(
      PercChainTip.hash(ledgerWithFull(fullBlock)),
      PercChainTip.hash(ledgerWithFull(truncatedBlock)),
    );
  });
}