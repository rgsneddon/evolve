import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_block_display_label.dart';

void main() {
  test('labels transfer blocks as Manual tx', () {
    final block = PercBlock(
      index: 3,
      timestamp: DateTime.utc(2026, 7, 6),
      treasuryEmitted: PercAmount.zero,
      triggerUsername: 'alice',
      transactions: [
        PercTransaction(
          id: 'tx-1',
          kind: PercTxKind.transfer,
          amount: PercAmount.fromPerc(0.00000010),
          timestamp: DateTime.utc(2026, 7, 6),
          fromUsername: 'alice',
          toUsername: 'bob',
          blockIndex: 3,
          confirmations: 1,
        ),
        PercTransaction(
          id: 'tx-fee',
          kind: PercTxKind.feeBurn,
          amount: PercAmount.smallestUnit,
          timestamp: DateTime.utc(2026, 7, 6),
          fromUsername: 'alice',
          blockIndex: 3,
          confirmations: 1,
        ),
      ],
    );

    expect(PercBlockDisplayLabel.forBlock(block), 'Manual tx');
    expect(PercBlockDisplayLabel.hasTransfer(block), isTrue);
    expect(PercBlockDisplayLabel.transferTransactions(block), hasLength(1));
    expect(
      PercBlockDisplayLabel.transferTransactions(block).first.kind,
      PercTxKind.transfer,
    );
  });
}