import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PercNetworkCoordinator.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });
  test('registrations with same username on different devices get unique addresses', () {
    final evolveAndroid = PercLedger.empty();
    evolveAndroid.ensureTreasuryAccount();
    evolveAndroid.setupTreasuryPassword('password12345');
    evolveAndroid.launchBlockchain();
    evolveAndroid.register('traveler', 'password12345');

    final myPercAndroid = PercLedger.empty();
    myPercAndroid.ensureTreasuryAccount();
    myPercAndroid.setupTreasuryPassword('password12345');
    myPercAndroid.launchBlockchain();
    myPercAndroid.register('traveler', 'password12345');

    final evolveWindows = PercLedger.empty();
    evolveWindows.ensureTreasuryAccount();
    evolveWindows.setupTreasuryPassword('password12345');
    evolveWindows.launchBlockchain();
    evolveWindows.register('traveler', 'password12345');

    final addresses = {
      evolveAndroid.account('traveler')!.address,
      myPercAndroid.account('traveler')!.address,
      evolveWindows.account('traveler')!.address,
    };
    expect(addresses, hasLength(3));
  });

  test('send records recipient address on pending transfer', () {
    final sender = PercLedger.empty();
    sender.ensureTreasuryAccount();
    sender.setupTreasuryPassword('password12345');
    sender.launchBlockchain();
    sender.register('alice', 'password12345');
    sender.login('alice', 'password12345');
    sender.creditScenario(username: 'alice', percentChance: 50);

    final receiverAddr = PercAuth.deriveAddress('bob', 'my-perc-salt');
    sender.ensureRemoteAccount(username: 'bob', address: receiverAddr);

    sender.send(
      fromUsername: 'alice',
      toAddress: receiverAddr,
      amount: PercAmount.fromPerc(0.00000004),
      deliverInstantly: false,
    );

    expect(sender.pendingInboundTransfers, hasLength(1));
    expect(sender.pendingInboundTransfers.first.toAddress, receiverAddr);
    expect(sender.pendingInboundTransfers.first.toUsername, 'bob');
  });

  test('relay merge ignores same-username wallet with different address', () {
    final sender = PercLedger.empty();
    sender.ensureTreasuryAccount();
    sender.setupTreasuryPassword('password12345');
    sender.launchBlockchain();
    sender.register('alice', 'password12345');
    sender.login('alice', 'password12345');
    sender.creditScenario(username: 'alice', percentChance: 50);

    final myPercAddr = PercAuth.deriveAddress('traveler', 'my-perc-device-salt');
    sender.ensureRemoteAccount(username: 'traveler', address: myPercAddr);
    sender.send(
      fromUsername: 'alice',
      toAddress: myPercAddr,
      amount: PercAmount.fromPerc(0.00000006),
      deliverInstantly: false,
    );

    final evolveWindows = PercLedger.empty();
    evolveWindows.ensureTreasuryAccount();
    evolveWindows.setupTreasuryPassword('password12345');
    evolveWindows.launchBlockchain();
    evolveWindows.register('traveler', 'password12345');
    evolveWindows.login('traveler', 'password12345');
    final windowsAddr = evolveWindows.account('traveler')!.address;
    expect(windowsAddr, isNot(myPercAddr));

    evolveWindows.mergePendingInboundFromPeer(sender);

    expect(evolveWindows.pendingInboundTransfers, isEmpty);
    expect(evolveWindows.pendingInboundFor('traveler'), isEmpty);
    expect(evolveWindows.account('traveler')!.balance, PercAmount.zero);
  });

  test(
    'seed peer with local traveler username but foreign toAddress stays clean',
    () {
      final evolveWindows = PercLedger.empty();
      evolveWindows.ensureTreasuryAccount();
      evolveWindows.setupTreasuryPassword('password12345');
      evolveWindows.launchBlockchain();
      evolveWindows.register('traveler', 'password12345');
      evolveWindows.login('traveler', 'password12345');
      final windowsAddr = evolveWindows.account('traveler')!.address;

      final myPercAddr = PercAuth.deriveAddress('traveler', 'my-perc-device-salt');
      expect(windowsAddr, isNot(myPercAddr));

      final seedRelay = PercLedger.empty();
      seedRelay.ensureTreasuryAccount();
      seedRelay.setupTreasuryPassword('password12345');
      seedRelay.launchBlockchain();
      seedRelay.register('alice', 'password12345');
      seedRelay.login('alice', 'password12345');
      seedRelay.accounts['traveler'] = evolveWindows.account('traveler')!;

      final amount = PercAmount.fromPerc(0.00000007);
      final sentAt = DateTime.now().toUtc();
      seedRelay.pendingInboundTransfers.add(
        PercPendingInboundTransfer(
          id: 'tx-seed-mismatch',
          fromUsername: 'alice',
          toUsername: 'traveler',
          toAddress: myPercAddr,
          amount: amount,
          sentAt: sentAt,
        ),
      );

      evolveWindows.mergePendingInboundFromPeer(seedRelay);
      evolveWindows.applyInboundRelayFromSender(seedRelay);
      evolveWindows.refreshPendingInboundTransfers();

      expect(evolveWindows.pendingInboundTransfers, isEmpty);
      expect(evolveWindows.pendingInboundFor('traveler'), isEmpty);
      expect(
        evolveWindows.account('traveler')!.transactions.where(
          (tx) => tx.id == 'tx-seed-mismatch',
        ),
        isEmpty,
      );
      expect(evolveWindows.account('traveler')!.balance, PercAmount.zero);
    },
  );

  test(
    'logged-in third-party provider ignores relay aimed at foreign address',
    () async {
      final store = PercWalletStoreMemory();
      final evolveWindows = PercWalletProvider(store: store);
      await evolveWindows.initialize();
      await evolveWindows.setupTreasuryPassword('password12345');
      await evolveWindows.register('traveler', 'password12345');
      await evolveWindows.login('traveler', 'password12345');
      final windowsAddr = evolveWindows.addressForUsername('traveler');

      final sender = PercLedger.empty();
      sender.ensureTreasuryAccount();
      sender.setupTreasuryPassword('password12345');
      sender.launchBlockchain();
      sender.register('alice', 'password12345');
      sender.login('alice', 'password12345');
      sender.creditScenario(username: 'alice', percentChance: 50);

      final myPercAddr = PercAuth.deriveAddress('traveler', 'my-perc-android-salt');
      expect(windowsAddr, isNot(myPercAddr));
      sender.ensureRemoteAccount(username: 'traveler', address: myPercAddr);
      sender.send(
        fromUsername: 'alice',
        toAddress: myPercAddr,
        amount: PercAmount.fromPerc(0.00000005),
        deliverInstantly: false,
      );

      PercLedgerHub.instance.ledger.applyInboundRelayFromSender(sender);
      PercLedgerHub.instance.ledger.refreshPendingInboundTransfers();

      expect(evolveWindows.pendingInboundTransfers, isEmpty);
      expect(evolveWindows.balance, PercAmount.zero);
      expect(
        evolveWindows.transactions.where((tx) => tx.id == sender.pendingInboundTransfers.first.id),
        isEmpty,
      );
    },
  );

  test('only matching recipient address shows confirming inbound transfer', () {
    final myPerc = PercLedger.empty();
    myPerc.ensureTreasuryAccount();
    myPerc.setupTreasuryPassword('password12345');
    myPerc.launchBlockchain();
    myPerc.register('traveler', 'password12345');
    myPerc.login('traveler', 'password12345');
    final myPercAddr = myPerc.account('traveler')!.address;

    final evolveWindows = PercLedger.empty();
    evolveWindows.ensureTreasuryAccount();
    evolveWindows.setupTreasuryPassword('password12345');
    evolveWindows.launchBlockchain();
    evolveWindows.register('traveler', 'password12345');
    evolveWindows.login('traveler', 'password12345');

    final sentAt = DateTime.now().toUtc();
    evolveWindows.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'tx-cross-device',
        fromUsername: 'alice',
        toUsername: 'traveler',
        toAddress: myPercAddr,
        amount: PercAmount.fromPerc(0.00000003),
        sentAt: sentAt,
      ),
    );

    expect(evolveWindows.pendingInboundFor('traveler'), isEmpty);

    myPerc.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'tx-cross-device',
        fromUsername: 'alice',
        toUsername: 'traveler',
        toAddress: myPercAddr,
        amount: PercAmount.fromPerc(0.00000003),
        sentAt: sentAt,
      ),
    );

    expect(myPerc.pendingInboundFor('traveler'), hasLength(1));
    expect(
      myPerc.pendingInboundFor('traveler').first.toAddress,
      myPercAddr,
    );
  });
}