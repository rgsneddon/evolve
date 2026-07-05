import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  tearDown(() {
    PercChainConstants.walletSessionMaxDurationOverride = null;
    PercChainConstants.walletSessionIdleTimeoutOverride = null;
  });

  test('dormant wallet logs out after max duration and idle timeout', () {
    PercChainConstants.walletSessionMaxDurationOverride = const Duration(minutes: 8);
    PercChainConstants.walletSessionIdleTimeoutOverride = const Duration(minutes: 7);

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
  });

  test('recent user activity extends dormant logout beyond eight minutes', () {
    PercChainConstants.walletSessionMaxDurationOverride = const Duration(minutes: 8);
    PercChainConstants.walletSessionIdleTimeoutOverride = const Duration(minutes: 7);

    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    final loginAt = DateTime.utc(2026, 7, 5, 12, 0);
    ledger.login('alice', 'password12345', now: loginAt);

    final activeAt = loginAt.add(const Duration(minutes: 6));
    ledger.touchWalletSessionActivity(now: activeAt);

    expect(
      ledger.isWalletSessionExpired(now: loginAt.add(const Duration(minutes: 8))),
      isFalse,
    );
    expect(
      ledger.isWalletSessionExpired(now: activeAt.add(const Duration(minutes: 7))),
      isTrue,
    );
    expect(
      ledger.walletSessionRemaining(now: activeAt),
      const Duration(minutes: 7),
    );
  });

  test('logout clears session timestamps', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    ledger.login('alice', 'password12345');

    expect(ledger.sessionStartedAt, isNotNull);
    expect(ledger.sessionLastActivityAt, isNotNull);
    ledger.logout();
    expect(ledger.sessionUsername, isNull);
    expect(ledger.sessionStartedAt, isNull);
    expect(ledger.sessionLastActivityAt, isNull);
  });

  test('persisted session without timestamps is treated as expired', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    ledger.sessionUsername = 'alice';

    expect(ledger.isWalletSessionExpired(), isTrue);
    expect(ledger.walletSessionRemaining(), Duration.zero);
  });

  test('session timestamps round-trip through ledger json', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.register('alice', 'password12345');
    final loginAt = DateTime.utc(2026, 7, 5, 9, 30);
    ledger.login('alice', 'password12345', now: loginAt);

    final restored = PercLedger.fromJson(ledger.toJson());
    expect(restored.sessionUsername, 'alice');
    expect(restored.sessionStartedAt, loginAt);
    expect(restored.sessionLastActivityAt, loginAt);
  });
}