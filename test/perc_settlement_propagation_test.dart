import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_staking.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

import 'support/two_device_harness.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
  });

  test('commitAfterScenario propagateSettlementWitnesses debits registered sender', () async {
    final devices = TwoDeviceHarness.create();
    devices.linkDevices();
    devices.fundSender();
    devices.loginSender();

    final amount = PercAmount.fromPerc(0.00000005);
    devices.sendAndRelay(amount, deliverInstantly: false);
    devices.loginReceiver();

    final aliceBefore = devices.sender.account('alice')!.balance;

    devices.receiver.advanceScenarioBlock(
      'bob',
      senderPeerResolver: (from) => from == 'alice' ? devices.sender : null,
    );
    expect(devices.receiver.settlementWitnesses, hasLength(1));

    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);
    final hub = PercLedgerHub.instance;
    hub.ledger.importPeerLedger(devices.receiver, force: true);
    hub.ledger.login(devices.receiverUser, devices.password);

    PercNetworkCoordinator.instance.settlementPeerTargets[devices.senderUser] =
        devices.sender;
    await hub.commitAfterScenario();

    expect(devices.sender.pendingInboundFor(devices.receiverUser), isEmpty);
    expect(
      devices.sender.account(devices.senderUser)!.balance.microUnits,
      (aliceBefore - amount - PercChainConstants.sendTransactionFee +
              PercStaking.rewardPerBlock)
          .microUnits,
    );
    expect(
      devices.sender.account(devices.senderUser)!.transactions.any(
            (tx) =>
                tx.kind == PercTxKind.transfer &&
                tx.amount == amount &&
                tx.isConfirmed,
          ),
      isTrue,
    );
  });
}