import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  tearDown(() {
    PercChainConstants.walletSessionTimeoutOverride = null;
  });

  test('wallet session expires after configured timeout', () {
    PercChainConstants.walletSessionTimeoutOverride = const Duration(minutes: 8);

    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.launchBlockchain();
    ledger.register('alice', 'password12345');

    final loginAt = DateTime.utc(2026, 7, 5, 12, 0);
    ledger.login('alice', 'password12345', now: loginAt);

    expect(ledger.isLoggedIn, isTrue);
    expect(
      ledger.isWalletSessionExpired(now: loginAt.add(const Duration(minutes: 7, seconds: 59))),
      isFalse,
    );
    expect(
      ledger.isWalletSessionExpired(now: loginAt.add(const Duration(minutes: 8))),
      isTrue,
    );
    expect(
      ledger.walletSessionRemaining(now: loginAt.add(const Duration(minutes: 2))),
      const Duration(minutes: 6),
    );
  });

  test('logout clears session start timestamp', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    ledger.login('alice', 'password12345');

    expect(ledger.sessionStartedAt, isNotNull);
    ledger.logout();
    expect(ledger.sessionUsername, isNull);
    expect(ledger.sessionStartedAt, isNull);
  });

  test('persisted session without start time is treated as expired', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    ledger.sessionUsername = 'alice';

    expect(ledger.isWalletSessionExpired(), isTrue);
    expect(ledger.walletSessionRemaining(), Duration.zero);
  });

  test('sessionStartedAt round-trips through ledger json', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    final loginAt = DateTime.utc(2026, 7, 5, 9, 30);
    ledger.login('alice', 'password12345', now: loginAt);

    final restored = PercLedger.fromJson(ledger.toJson());
    expect(restored.sessionUsername, 'alice');
    expect(restored.sessionStartedAt, loginAt);
  });
}