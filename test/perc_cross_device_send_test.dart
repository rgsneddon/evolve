import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';

import 'support/two_device_harness.dart';

void main() {
  test('receiver ledger merges pending inbound from sender relay state', () {
    final devices = TwoDeviceHarness.create(
      senderUser: 'android_user',
      receiverUser: 'windows_user',
      password: 'password12345',
    );
    devices.linkDevices();
    devices.fundSender(percentChance: 80);
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000010);
    devices.send(amount, deliverInstantly: true);

    expect(devices.sender.pendingInboundFor('windows_user'), hasLength(1));
    expect(devices.sender.account('windows_user')!.balance, PercAmount.zero);
    expect(devices.sender.account('android_user')!.transactions, isNotEmpty);

    devices.relayInitiationToReceiver();
    devices.loginReceiver();

    expect(devices.receiver.pendingInboundFor('windows_user'), hasLength(1));
    expect(devices.receiver.account('windows_user')!.balance, PercAmount.zero);

    devices.crossDeviceScenarioAndSettle();
    expect(devices.receiver.pendingInboundFor('windows_user'), isEmpty);
    expect(devices.receiver.account('windows_user')!.balance, amount);
    expect(
      devices.receiver.account('windows_user')!.transactions.any(
            (tx) => tx.amount == amount && tx.isConfirmed,
          ),
      isTrue,
    );
  });
}