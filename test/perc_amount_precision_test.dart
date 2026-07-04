import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('parses 0.00000001 PERC without floating-point drift', () {
    const expected = PercAmount.smallestUnit;
    expect(PercAmount.tryParseDecimalString('0.00000001'), expected);
    expect(PercAmount.tryParseDisplay('0.00000001'), expected);
    expect(expected.displayFixed8, '0.00000001');
  });

  test('rejects more than 8 decimal places', () {
    expect(PercAmount.tryParseDecimalString('0.000000001'), isNull);
    expect(PercAmount.tryParseDecimalString('1.123456789'), isNull);
  });

  test('parses fractional and whole PERC amounts precisely', () {
    expect(
      PercAmount.tryParseDecimalString('1.5')?.microUnits,
      150000000,
    );
    expect(
      PercAmount.tryParseDecimalString('.00000005')?.displayFixed8,
      '0.00000005',
    );
    expect(
      PercAmount.tryParseDecimalString('283000000')?.microUnits,
      283000000 * PercAmount.unitsPerPerc,
    );
  });

  test('user wallet receives smallest unit 0.00000001 PERC', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    final credit = ledger.creditScenario(username: 'alice', percentChance: 50);
    expect(credit.status, PercFaucetCreditStatus.credited);

    const oneCent = PercAmount.smallestUnit;

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: oneCent,
    );
    ledger.login('bob', 'password123');
    expect(ledger.account('bob')!.balance, oneCent);
  });

  test('treasury wallet receives smallest unit 0.00000001 PERC', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    final credit = ledger.creditScenario(username: 'alice', percentChance: 50);
    expect(credit.status, PercFaucetCreditStatus.credited);

    const oneCent = PercAmount.smallestUnit;

    final tx = ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, PercChainConstants.treasuryUsername),
      amount: oneCent,
    );

    expect(tx.kind, PercTxKind.transfer);
    expect(tx.amount, oneCent);
    expect(tx.toUsername, PercChainConstants.treasuryUsername);
    expect(
      ledger
          .account(PercChainConstants.treasuryUsername)!
          .transactions
          .any((t) => t.id == tx.id && t.amount == oneCent),
      isTrue,
    );
  });

  test('ledger rejects amounts below 1 cent', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    final credit = ledger.creditScenario(username: 'alice', percentChance: 50);
    expect(credit.status, PercFaucetCreditStatus.credited);

    expect(
      () => ledger.send(
        fromUsername: 'alice',
        toAddress: _addr(ledger, 'bob'),
        amount: PercAmount.zero,
      ),
      throwsStateError,
    );
  });
}