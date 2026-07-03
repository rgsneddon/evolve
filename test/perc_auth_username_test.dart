import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  test('validateUsername rejects reserved treasury name', () {
    expect(
      PercAuth.validateUsername(PercChainConstants.treasuryUsername),
      isNotNull,
    );
  });

  test('validateUsername accepts custom usernames', () {
    expect(PercAuth.validateUsername('parish_ward_42'), isNull);
  });

  test('register rejects reserved treasury username', () {
    final ledger = PercLedger.empty();
    expect(
      () => ledger.register(PercChainConstants.treasuryUsername, 'password123'),
      throwsStateError,
    );
  });

  test('user can register before treasury password is set', () {
    final ledger = PercLedger.empty()..ensureTreasuryAccount();
    expect(ledger.treasuryNeedsPasswordSetup(), isTrue);

    final acc = ledger.register('alice', 'password123');
    ledger.login('alice', 'password123');

    expect(acc.username, 'alice');
    expect(ledger.sessionUsername, 'alice');
    expect(ledger.treasuryNeedsPasswordSetup(), isTrue);
    expect(ledger.isBlockchainLaunched, isFalse);
  });
}