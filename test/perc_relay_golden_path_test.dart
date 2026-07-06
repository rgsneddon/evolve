import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_block_display_label.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'helpers/send_relay_fixture.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('send → serialize → acknowledgeRelayTransfers credits receiver with same tx.id', () {
    final built = SendRelayFixture.build();
    final sender = built.ledger;
    final transferTxId = built.transferTxId;


    expect(
      sender.blocks.any((b) => b.transactions.any((t) => t.id == transferTxId)),
      isTrue,
    );
    expect(sender.account('android_user')!.transactions.any((t) => t.id == transferTxId), isTrue);

    final receiver = PercLedger.empty();
    _seed(receiver);
    receiver.register('windows_user', 'password12345');
    receiver.register('android_user', 'password12345');
    for (var i = 0; receiver.blockHeight <= sender.blockHeight; i++) {
      receiver.blocks.add(
        PercBlock(
          index: receiver.blocks.length,
          timestamp: DateTime.now().toUtc(),
          transactions: const [],
          treasuryEmitted: PercAmount.zero,
          scenarioLabel: 'Receiver ahead $i',
        ),
      );
    }
    expect(receiver.blockHeight, greaterThan(sender.blockHeight));

    final relay = PercLedger.fromJson(sender.toJson());
    receiver.mergeNetworkStateFromPeer(relay);

    final promoted = receiver.blocks.lastWhere(PercBlockDisplayLabel.hasTransfer);
    final canonicalIndex = receiver.blocks.length - 1;
    expect(promoted.index, canonicalIndex);
    expect(
      PercBlockDisplayLabel.transferTransactions(promoted).first.id,
      transferTxId,
    );
    expect(
      PercBlockDisplayLabel.transferTransactions(promoted).first.blockIndex,
      canonicalIndex,
    );
    expect(receiver.microblocksPerBlock, PercChainConstants.microblocksPerBlock);

    receiver.login('windows_user', 'password12345');
    receiver.refreshPendingInboundForSession();
    expect(receiver.account('windows_user')!.balance, PercAmount.fromPerc(0.00000005));
    expect(receiver.pendingInboundFor('windows_user'), isEmpty);
  });
}