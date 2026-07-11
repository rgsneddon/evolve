import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_app/perc/models/perc_amount.dart';
import 'package:evolve_app/perc/models/perc_transaction.dart';
import 'package:evolve_app/perc/perc_chain_constants.dart';
import 'package:evolve_app/perc/providers/perc_wallet_provider.dart';
import 'package:evolve_app/perc/services/perc_ledger.dart';
import 'package:evolve_app/perc/services/perc_ledger_hub.dart';
import 'package:evolve_app/perc/services/perc_network_coordinator.dart';
import 'package:evolve_app/perc/services/perc_wallet_store_memory.dart';

import 'support/two_device_harness.dart';

/// Plan harness: sender online → recipient offline at send → relay PUT →
/// recipient login / burst sync → balance credited, sender debited, no scenario.
void main() {
  setUp(() {
    PercNetworkCoordinator.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test(
    'offline recipient burst credits balance and propagates sender debit without scenario',
    () async {
      final devices = TwoDeviceHarness.create();
      devices.linkDevices();
      devices.fundSender();
      devices.loginSender();

      final amount = PercAmount.fromPerc(0.00000008);
      devices.send(amount, deliverInstantly: false);
      expect(devices.sender.pendingInboundFor(devices.receiverUser), hasLength(1));

      final hub = PercLedgerHub.instance;
      TwoDeviceHarness.seed(hub.ledger);
      hub.ledger.register(devices.receiverUser, devices.password);
      hub.ledger.login(devices.receiverUser, devices.password);
      hub.ledger.mergeDiscoverableAccounts(devices.sender);

      final coordinator = PercNetworkCoordinator.instance;
      await coordinator.bind(hub);
      await coordinator.onSessionStarted(devices.receiverUser);

      PercNetworkCoordinator.instance.settlementPeerTargets[devices.senderUser] =
          devices.sender;

      final aliceBefore = devices.sender.account(devices.senderUser)!.balance;
      expect(hub.ledger.sessionBalance, PercAmount.zero);

      await coordinator.pushLedgerToRecipient(
        ledger: devices.sender,
        username: devices.receiverUser,
      );

      coordinator.scheduleInboundBurst(
        senderUsernames: [devices.senderUser],
      );
      await coordinator.runBurstInboundCycleForTest();

      expect(hub.ledger.pendingInboundFor(devices.receiverUser), isEmpty);
      expect(hub.ledger.sessionBalance, amount);
      expect(hub.ledger.settlementWitnesses, hasLength(1));

      expect(devices.sender.pendingInboundFor(devices.receiverUser), isEmpty);
      final postDebit =
          aliceBefore - amount - PercChainConstants.sendTransactionFee;
      expect(devices.sender.account(devices.senderUser)!.balance, postDebit);
      expect(
        devices.sender.account(devices.senderUser)!.transactions.any(
              (tx) =>
                  tx.kind == PercTxKind.transfer &&
                  tx.amount == amount &&
                  tx.isConfirmed,
            ),
        isTrue,
      );

      // ignore: avoid_print
      print(
        'OFFLINE_RECOVERY: receiver=${amount.displayFixed8} '
        'sender_debited=${devices.sender.account(devices.senderUser)!.balance.displayFixed8}',
      );
    },
  );

  test(
    'refreshInboundNow on logged-in recipient completes offline send end-to-end',
    () async {
      final store = PercWalletStoreMemory();
      final wallet = PercWalletProvider(store: store);
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password123');
      await wallet.register('bob', 'password123');

      final sender = PercLedger.empty();
      TwoDeviceHarness.seed(sender);
      sender.register('alice', 'password123');
      sender.login('alice', 'password123');
      sender.mergeDiscoverableAccounts(PercLedgerHub.instance.ledger);
      sender.creditScenario(username: 'alice', percentChance: 50);

      final bobAddr = wallet.address;

      final amount = PercAmount.fromPerc(0.00000006);
      sender.send(
        fromUsername: 'alice',
        toAddress: bobAddr,
        amount: amount,
        deliverInstantly: false,
      );

      PercNetworkCoordinator.instance.settlementPeerTargets['alice'] = sender;
      final aliceBefore = sender.account('alice')!.balance;

      await wallet.login('bob', 'password123');
      expect(wallet.balance, PercAmount.zero);

      await PercNetworkCoordinator.instance.pushLedgerToRecipient(
        ledger: sender,
        username: 'bob',
      );

      await wallet.refreshInboundNow();
      await PercNetworkCoordinator.instance.runBurstInboundCycleForTest();

      expect(wallet.pendingInboundTransfers, isEmpty);
      expect(wallet.balance, amount);
      expect(sender.pendingInboundFor('bob'), isEmpty);
      final postDebit =
          aliceBefore - amount - PercChainConstants.sendTransactionFee;
      expect(sender.account('alice')!.balance, postDebit);
    },
  );
}
