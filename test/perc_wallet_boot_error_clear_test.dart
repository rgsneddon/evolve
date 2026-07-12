import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    PercNetworkCoordinator.sessionStartThrowsForTest = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercNetworkCoordinator.sessionStartThrowsForTest = false;
    PercLedgerHub.resetForTest();
  });

  Future<PercWalletProvider> bootPersistedSession() async {
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

  test('initialize leaves errorMessage null with persisted session', () async {
    final wallet = await bootPersistedSession();
    expect(wallet.isLoggedIn, isTrue);
    expect(wallet.errorMessage, isNull);
  });

  test('initialize clears pre-seeded wallet_err_generic on successful boot',
      () async {
    final store = PercWalletStoreMemory();
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    ledger.login('alice', 'password12345', now: DateTime.now().toUtc());
    await store.save(ledger);

    final wallet = PercWalletProvider(store: store);
    wallet.errorMessage = 'wallet_err_generic';
    await wallet.initialize();

    expect(wallet.isLoggedIn, isTrue);
    expect(wallet.errorMessage, isNull);
  });

  test(
    'login does not persist wallet_err_generic when network session attach fails',
    () async {
      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.register('alice', 'password12345');
      await wallet.logout();

      PercNetworkCoordinator.sessionStartThrowsForTest = true;
      await wallet.login('alice', 'password12345');

      expect(wallet.isLoggedIn, isTrue);
      expect(wallet.hasAppAccess, isTrue);
      expect(wallet.errorMessage, isNull);
    },
  );

  test('credential errors are not cleared by stale-boot scrubber', () async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');
    await wallet.logout();

    await wallet.login('alice', 'wrong-password');

    expect(wallet.errorMessage, 'wallet_err_invalid_password');
    wallet.clearStaleBootErrorForTest();
    expect(wallet.errorMessage, 'wallet_err_invalid_password');
  });
}