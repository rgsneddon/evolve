import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercChainConstants.walletSessionMaxDurationOverride =
        const Duration(minutes: 8);
    PercChainConstants.walletSessionIdleTimeoutOverride =
        const Duration(minutes: 7);
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercChainConstants.walletSessionMaxDurationOverride = null;
    PercChainConstants.walletSessionIdleTimeoutOverride = null;
    PercLedgerHub.resetForTest();
  });

  Future<PercWalletProvider> bootWallet() async {
    final store = PercWalletStoreMemory();
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    ledger.login('alice', 'password12345', now: DateTime.now().toUtc());
    await store.save(ledger);

    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    return wallet;
  }

  void backdateSession({Duration by = const Duration(minutes: 9)}) {
    final ledger = PercLedgerHub.instance.ledger;
    final stale = DateTime.now().toUtc().subtract(by);
    ledger.sessionStartedAt = stale;
    ledger.sessionLastActivityAt = stale;
  }

  test('session stays signed in while seed connection is active', () async {
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    final wallet = await bootWallet();
    backdateSession();
    PercLedgerHub.instance.network.setSeedConnectedForTest(true);

    expect(wallet.isLoggedIn, isTrue);
    wallet.checkSessionTimeout();
    expect(wallet.isLoggedIn, isTrue);
    expect(wallet.sessionTimedOut, isFalse);

    PercNetworkCoordinator.disableLiveNodesForTests = true;
  });

  test('session expires after idle when seed connection is lost', () async {
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    final wallet = await bootWallet();
    backdateSession();
    PercLedgerHub.instance.network.setSeedConnectedForTest(false);

    expect(wallet.isLoggedIn, isTrue);
    wallet.checkSessionTimeout();
    await Future<void>.delayed(Duration.zero);
    expect(wallet.isLoggedIn, isFalse);
    expect(wallet.sessionTimedOut, isTrue);

    PercNetworkCoordinator.disableLiveNodesForTests = true;
  });

  test('persisted sign-in survives boot when session timestamps are fresh',
      () async {
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    final wallet = await bootWallet();
    expect(wallet.isLoggedIn, isTrue);
    expect(wallet.hasAppAccess, isTrue);

    PercNetworkCoordinator.disableLiveNodesForTests = true;
  });
}