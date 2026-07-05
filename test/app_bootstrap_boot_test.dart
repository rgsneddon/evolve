import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
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

  test('initialize completes quickly when persisted session is expired', () async {
    final store = PercWalletStoreMemory();
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    ledger.sessionUsername = 'alice';
    await store.save(ledger);

    final wallet = PercWalletProvider(store: store);

    final elapsed = await _time(wallet.initialize());
    expect(wallet.isReady, isTrue);
    expect(wallet.isLoggedIn, isFalse);
    expect(wallet.sessionTimedOut, isTrue);
    expect(elapsed, lessThan(const Duration(seconds: 2)));
  });
}

Future<Duration> _time(Future<void> action) async {
  final stopwatch = Stopwatch()..start();
  await action;
  stopwatch.stop();
  return stopwatch.elapsed;
}