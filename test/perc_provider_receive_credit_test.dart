import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_network_rendezvous.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/two_device_harness.dart';

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
    'sender provider commitAfterSend publishes relay hint under alice session',
    () async {
      final store = PercWalletStoreMemory();
      final senderWallet = PercWalletProvider(store: store);
      await senderWallet.initialize();
      await senderWallet.setupTreasuryPassword('password123');

      final remoteBob = PercLedger.empty();
      TwoDeviceHarness.seed(remoteBob);
      remoteBob.register('bob', 'password123');

      await senderWallet.register('alice', 'password123');
      PercLedgerHub.instance.ledger.mergeDiscoverableAccounts(remoteBob);
      PercLedgerHub.instance.ledger.launchBlockchain();
      PercLedgerHub.instance.ledger.consumeBlockchainLaunchEvent();

      await senderWallet.login('alice', 'password123');
      await senderWallet.creditScenario(outcomeScore: 50, memo: 'fund');

      final bobAddr = remoteBob.account('bob')!.address;
      final amount = PercAmount.fromPerc(0.00000006);

      expect(
        PercNetworkCoordinator.instance.activeUsernameForTest,
        'alice',
      );

      await senderWallet.send(
        toAddress: bobAddr,
        amountText: amount.displayFixed8,
        sendAuthPassword: 'password123',
      );

      expect(senderWallet.errorMessage, isNull);

      final hints = await const PercNetworkRendezvous().fetchInboundRelayHints(
        recipientUsername: 'bob',
      );
      expect(hints, isNotEmpty);
      expect(hints.first.senderUsername, 'alice');
      expect(
        PercNetworkCoordinator.instance.activeUsernameForTest,
        'alice',
      );
    },
  );

  test(
    'logged-in receiver credits via hint poll after cross-device relay PUT',
    () async {
      final store = PercWalletStoreMemory();
      final receiverWallet = PercWalletProvider(store: store);
      await receiverWallet.initialize();
      await receiverWallet.setupTreasuryPassword('password123');
      await receiverWallet.register('bob', 'password123');

      final sender = PercLedger.empty();
      TwoDeviceHarness.seed(sender);
      sender.register('alice', 'password123');
      sender.login('alice', 'password123');
      sender.mergeDiscoverableAccounts(PercLedgerHub.instance.ledger);
      sender.creditScenario(username: 'alice', percentChance: 50);

      final amount = PercAmount.fromPerc(0.00000006);
      sender.send(
        fromUsername: 'alice',
        toAddress: receiverWallet.address,
        amount: amount,
        deliverInstantly: false,
      );

      PercNetworkCoordinator.instance.settlementPeerTargets['alice'] = sender;

      await receiverWallet.login('bob', 'password123');
      expect(
        PercNetworkCoordinator.instance.activeUsernameForTest,
        'bob',
      );
      expect(receiverWallet.balance, PercAmount.zero);

      await const PercNetworkRendezvous().relayLedger(
        username: 'alice',
        ledger: sender,
        notifyRecipientUsername: 'bob',
      );

      await PercNetworkCoordinator.instance.pollInboundRelayHintsForTest();

      expect(receiverWallet.pendingInboundTransfers, isEmpty);
      expect(receiverWallet.balance, amount);
    },
  );

  test(
    'refreshInboundNow updates provider balance after 1-confirmation relay',
    () async {
      final store = PercWalletStoreMemory();
      final receiverWallet = PercWalletProvider(store: store);
      await receiverWallet.initialize();
      await receiverWallet.setupTreasuryPassword('password123');
      await receiverWallet.register('bob', 'password123');

      final sender = PercLedger.empty();
      TwoDeviceHarness.seed(sender);
      sender.register('alice', 'password123');
      sender.login('alice', 'password123');
      sender.mergeDiscoverableAccounts(PercLedgerHub.instance.ledger);
      sender.creditScenario(username: 'alice', percentChance: 50);

      final amount = PercAmount.fromPerc(0.00000005);
      sender.send(
        fromUsername: 'alice',
        toAddress: receiverWallet.address,
        amount: amount,
        deliverInstantly: false,
      );

      PercNetworkCoordinator.instance.settlementPeerTargets['alice'] = sender;

      await receiverWallet.login('bob', 'password123');
      expect(receiverWallet.balance, PercAmount.zero);

      await const PercNetworkRendezvous().relayLedger(
        username: 'alice',
        ledger: sender,
        notifyRecipientUsername: 'bob',
      );

      await receiverWallet.refreshInboundNow();

      expect(receiverWallet.pendingInboundTransfers, isEmpty);
      expect(receiverWallet.balance, amount);
      expect(
        receiverWallet.transactions.any(
          (tx) => tx.amount == amount && tx.isConfirmed,
        ),
        isTrue,
      );
    },
  );

  test(
    'same-hub ledger send credits logged-in receiver provider immediately',
    () async {
      final store = PercWalletStoreMemory();
      final receiverWallet = PercWalletProvider(store: store);
      await receiverWallet.initialize();
      await receiverWallet.setupTreasuryPassword('password123');
      await receiverWallet.register('alice', 'password123');
      await receiverWallet.register('bob', 'password123');

      final ledger = PercLedgerHub.instance.ledger;
      ledger.launchBlockchain();
      ledger.consumeBlockchainLaunchEvent();
      ledger.creditScenario(username: 'alice', percentChance: 50);

      await receiverWallet.login('bob', 'password123');
      final bobBefore = receiverWallet.balance;
      final bobAddr = receiverWallet.address;
      final amount = PercAmount.fromPerc(0.00000004);

      ledger.send(
        fromUsername: 'alice',
        toAddress: bobAddr,
        amount: amount,
        deliverInstantly: false,
      );

      expect(receiverWallet.balance, bobBefore + amount);
      expect(
        receiverWallet.transactions.any(
          (tx) => tx.amount == amount && tx.isConfirmed,
        ),
        isTrue,
      );
      expect(
        PercNetworkCoordinator.instance.activeUsernameForTest,
        'bob',
      );
    },
  );
}