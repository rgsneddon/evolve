import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.launchBlockchain();
}

void main() {
  test('receiver ledger merges pending inbound from sender relay state', () {
    final sender = PercLedger.empty();
    _seed(sender);
    sender.register('android_user', 'password12345');
    sender.register('windows_user', 'password12345');
    sender.creditScenario(username: 'android_user', percentChance: 80);
    sender.login('android_user', 'password12345');

    final windowsAddr = sender.account('windows_user')!.address;
    final amount = PercAmount.fromPerc(0.00000010);

    sender.send(
      fromUsername: 'android_user',
      toAddress: windowsAddr,
      amount: amount,
      deliverInstantly: true,
    );

    expect(sender.pendingInboundFor('windows_user'), hasLength(1));
    expect(sender.account('windows_user')!.balance, PercAmount.zero);
    expect(sender.account('android_user')!.transactions, isNotEmpty);

    final receiver = PercLedger.fromJson(sender.toJson());
    receiver.login('windows_user', 'password12345');

    receiver.refreshPendingInboundForSession();
    expect(receiver.pendingInboundFor('windows_user'), isEmpty);
    expect(receiver.account('windows_user')!.balance, amount);
    expect(
      receiver.account('windows_user')!.transactions.any(
            (tx) => tx.amount == amount && tx.isConfirmed,
          ),
      isTrue,
    );
  });
}