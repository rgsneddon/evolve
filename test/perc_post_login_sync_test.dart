import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercLedgerHub.resetForTest();
  });

  test('login exposes app access before network session completes', () async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');
    await wallet.logout();

    expect(wallet.hasAppAccess, isFalse);

    final loginFuture = wallet.login('alice', 'password12345');
    expect(wallet.hasAppAccess, isTrue);
    expect(wallet.isPostLoginSyncing, isTrue);
    expect(wallet.isWalletConnectComplete, isFalse);

    await loginFuture;

    expect(wallet.isPostLoginSyncing, isFalse);
    expect(wallet.isWalletConnectComplete, isTrue);
  });
}