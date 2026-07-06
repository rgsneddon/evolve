import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_block_display_label.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('shorter sender relay merge appends transfer block on taller receiver chain', () {
    final receiver = PercLedger.empty();
    _seed(receiver);
    receiver.register('windows_user', 'password12345');
    receiver.register('android_user', 'password12345');
    receiver.blocks.add(
      PercBlock(
        index: receiver.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'Receiver ahead',
      ),
    );
    receiver.blocks.add(
      PercBlock(
        index: receiver.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'Receiver ahead 2',
      ),
    );
    receiver.blocks.add(
      PercBlock(
        index: receiver.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'Receiver ahead 3',
      ),
    );
    final heightBefore = receiver.blockHeight;

    final sender = PercLedger.empty();
    _seed(sender);
    sender.register('android_user', 'password12345');
    sender.register('windows_user', 'password12345');
    sender.creditScenario(username: 'android_user', percentChance: 80);
    sender.login('android_user', 'password12345');
    sender.send(
      fromUsername: 'android_user',
      toAddress: sender.account('windows_user')!.address,
      amount: PercAmount.fromPerc(0.00000005),
      deliverInstantly: true,
    );

    expect(receiver.blockHeight, greaterThan(sender.blockHeight));
    expect(
      sender.blocks.any(PercBlockDisplayLabel.hasTransfer),
      isTrue,
    );

    receiver.mergeNetworkStateFromPeer(sender);

    expect(receiver.blockHeight, heightBefore + 1);
    expect(receiver.blocks.any(PercBlockDisplayLabel.hasTransfer), isTrue);
    expect(receiver.microblocksPerBlock, PercChainConstants.microblocksPerBlock);
    final transferBlock = receiver.blocks.lastWhere(PercBlockDisplayLabel.hasTransfer);
    expect(
      PercBlockDisplayLabel.transferTransactions(transferBlock).first.amount,
      PercAmount.fromPerc(0.00000005),
    );
  });

  test('settle does not duplicate block when relay already merged transfer', () {
    final receiver = PercLedger.empty();
    _seed(receiver);
    receiver.register('bob', 'password12345');
    receiver.register('alice', 'password12345');

    final sender = PercLedger.empty();
    _seed(sender);
    sender.register('alice', 'password12345');
    sender.register('bob', 'password12345');
    sender.creditScenario(username: 'alice', percentChance: 80);
    sender.login('alice', 'password12345');
    sender.send(
      fromUsername: 'alice',
      toAddress: sender.account('bob')!.address,
      amount: PercAmount.fromPerc(0.00000001),
      deliverInstantly: true,
    );

    receiver.mergeNetworkStateFromPeer(sender);
    final blocksAfterMerge = receiver.blockHeight;
    receiver.login('bob', 'password12345');
    receiver.refreshPendingInboundForSession();

    expect(receiver.blockHeight, blocksAfterMerge);
    expect(receiver.account('bob')!.balance, PercAmount.fromPerc(0.00000001));
  });
}