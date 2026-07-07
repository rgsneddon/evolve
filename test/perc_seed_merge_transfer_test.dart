import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
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
  test('rendezvous-style sender ledger merge credits signed-in receiver', () {
    final receiver = PercLedger.empty();
    _seed(receiver);
    receiver.register('windows_user', 'password12345');
    receiver.login('windows_user', 'password12345');
    final windowsAddr = receiver.account('windows_user')!.address;

    final sender = PercLedger.empty();
    _seed(sender);
    sender.register('android_user', 'password12345');
    sender.ensureRemoteAccount(username: 'windows_user', address: windowsAddr);
    sender.creditScenario(username: 'android_user', percentChance: 80);
    sender.login('android_user', 'password12345');

    final amount = PercAmount.fromPerc(0.00000010);
    final sentTx = sender.send(
      fromUsername: 'android_user',
      toAddress: windowsAddr,
      amount: amount,
      deliverInstantly: true,
    );

    expect(sender.pendingInboundFor('windows_user'), hasLength(1));
    expect(
      sender.blocks.any(
        (b) => b.transactions.any((t) => t.kind == PercTxKind.transfer),
      ),
      isTrue,
    );
    expect(sender.microblocksPerBlock, PercChainConstants.microblocksPerBlock);

    expect(receiver.pendingInboundFor('windows_user'), isEmpty);
    expect(receiver.account('windows_user')!.balance, PercAmount.zero);

    receiver.mergeNetworkStateFromPeer(sender);
    receiver.refreshPendingInboundForSession();

    expect(receiver.pendingInboundFor('windows_user'), isEmpty);
    expect(receiver.account('windows_user')!.balance, amount);
    expect(
      receiver.account('windows_user')!.transactions.any(
            (tx) => tx.isConfirmed && tx.amount == amount,
          ),
      isTrue,
    );
    final transferBlock = receiver.blocks.lastWhere(PercBlockDisplayLabel.hasTransfer);
    expect(
      PercBlockDisplayLabel.transferTransactions(transferBlock).first.id,
      sentTx.id,
    );
  });
}