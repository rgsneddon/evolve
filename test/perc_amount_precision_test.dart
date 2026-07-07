import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_staking.dart';

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

  test('user wallet receives smallest unit 0.00000001 PERC on near-instant send', () {
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
      deliverInstantly: false,
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

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final before = treasury.balance;

    final tx = ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, PercChainConstants.treasuryUsername),
      amount: oneCent,
      deliverInstantly: false,
    );

    expect(tx.kind, PercTxKind.transfer);
    expect(tx.amount, oneCent);
    expect(tx.toUsername, PercChainConstants.treasuryUsername);
    expect(ledger.pendingInboundFor(PercChainConstants.treasuryUsername), isEmpty);
    expect(
      treasury.transactions.any(
        (t) =>
            t.kind == PercTxKind.transfer &&
            t.amount == oneCent &&
            t.fromUsername == 'alice' &&
            t.isConfirmed,
      ),
      isTrue,
    );
    final stakingPaid = treasury.transactions
        .where((t) => t.kind == PercTxKind.stakingReward)
        .fold<PercAmount>(
          PercAmount.zero,
          (sum, t) => sum + t.amount,
        );
    expect(treasury.balance, before + oneCent - stakingPaid);
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