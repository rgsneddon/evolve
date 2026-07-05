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

  test('validateUsername allows whitelisted mod_* ward moderators', () {
    expect(PercAuth.validateUsername('mod_ainsdale'), isNull);
  });

  test('validateUsername allows whitelisted ONS ward codes (s1*)', () {
    expect(PercAuth.validateUsername('e05000932'), isNull);
  });

  test('validateUsername rejects unknown mod_* aliases', () {
    expect(PercAuth.validateUsername('mod_not_a_real_ward'), isNotNull);
  });

  test('validateUsername rejects unknown ONS ward codes', () {
    expect(PercAuth.validateUsername('e05000000'), isNotNull);
  });

  test('register accepts whitelisted ONS ward code username', () {
    final ledger = PercLedger.empty();
    final acc = ledger.register('e05000932', 'password12345');
    expect(acc.username, 'e05000932');
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