import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_currency.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_staking.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.login(PercChainConstants.treasuryUsername, 'password123');
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('send fee is 0.00000001 PERC and burned on every transfer', () {
    expect(PercChainConstants.sendTransactionFee, PercAmount.smallestUnit);
    expect(
      PercCurrency.sendFeeNote(),
      'Network fee: 0.00000001 PERC per send (burned)',
    );
  });

  test('sender debits amount plus fee; fee is burned not credited to treasury', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    final credit = ledger.creditScenario(username: 'alice', percentChance: 50);
    expect(credit.status, PercFaucetCreditStatus.credited);

    final amount = PercAmount.fromPerc(0.00000010);
    const fee = PercChainConstants.sendTransactionFee;
    final aliceBefore = ledger.account('alice')!.balance;
    final treasuryBefore = ledger.account(PercChainConstants.treasuryUsername)!.balance;

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: amount,
    );

    expect(
      ledger.account('alice')!.balance,
      aliceBefore - amount - fee + PercStaking.rewardPerBlock,
    );
    expect(
      ledger.account(PercChainConstants.treasuryUsername)!.balance,
      treasuryBefore - PercStaking.rewardPerBlock,
    );
    expect(ledger.cumulativeBurnedPerc, fee);
    expect(
      ledger.account('alice')!.transactions.any(
            (t) => t.kind == PercTxKind.feeBurn && t.amount == fee,
          ),
      isTrue,
    );
    expect(ledger.pendingInboundFor('bob').single.amount, amount);
  });

  test('cumulative burned PERC accumulates across sends', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);
    ledger.account('alice')!.balance = PercAmount.fromPerc(0.001);

    const fee = PercChainConstants.sendTransactionFee;
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.smallestUnit,
    );
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.smallestUnit,
    );

    expect(ledger.cumulativeBurnedPerc, fee + fee);
  });

  test('reverted transfer returns amount only — burned fee is not refunded', () {
    PercChainConstants.walletOnlineReceiveDelayOverride =
        const Duration(seconds: 2);

    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final amount = PercAmount.fromPerc(0.00000010);
    const fee = PercChainConstants.sendTransactionFee;
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: amount,
    );
    final aliceAfterSend = ledger.account('alice')!.balance;
    final burnedAfterSend = ledger.cumulativeBurnedPerc;
    final sentAt = ledger.pendingInboundFor('bob').single.sentAt;

    ledger.refreshPendingInboundTransfers(
      now: sentAt.add(const Duration(seconds: 3)),
    );

    expect(ledger.cumulativeBurnedPerc, burnedAfterSend);
    expect(ledger.cumulativeBurnedPerc, fee);
    expect(
      ledger.account('alice')!.balance,
      aliceAfterSend + amount + PercStaking.rewardPerBlock,
    );
    expect(
      ledger.account('alice')!.balance,
      isNot(aliceAfterSend + amount + fee + PercStaking.rewardPerBlock),
    );
  });

  test('send rejects when balance cannot cover amount and fee', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    final alice = ledger.account('alice')!;
    alice.balance = PercChainConstants.sendTransactionFee;

    expect(
      () => ledger.send(
        fromUsername: 'alice',
        toAddress: _addr(ledger, 'bob'),
        amount: PercAmount.smallestUnit,
      ),
      throwsStateError,
    );
  });

  test('cumulative burned PERC persists in ledger JSON', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);
    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.smallestUnit,
    );

    final restored = PercLedger.fromJson(ledger.toJson());
    expect(restored.cumulativeBurnedPerc, PercChainConstants.sendTransactionFee);
  });
}