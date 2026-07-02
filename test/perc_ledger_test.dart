import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
}

void main() {
  test('first scenario mints 1 PERC to treasury rgsneddon', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      scenarioLabel: 'Test',
    );

    expect(result.status, PercFaucetCreditStatus.credited);
    expect(ledger.cumulativeTreasuryMinted, PercAmount.fromPerc(1));
    expect(ledger.blocks.length, 1);
    expect(ledger.blocks.first.treasuryEmitted, PercAmount.fromPerc(1));
    expect(
      ledger.treasuryBalance,
      PercAmount.fromPerc(1) - result.reward!.total,
    );
  });

  test('scenario credit adds base 0.00000050 PERC to user', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('bob', 'password123');

    final result = ledger.creditScenario(username: 'bob', percentChance: 42);
    expect(result.status, PercFaucetCreditStatus.credited);
    final bob = ledger.account('bob')!;
    expect(bob.balance.microUnits, greaterThanOrEqualTo(50));
    expect(bob.transactions, isNotEmpty);
  });

  test('any user including treasury can draw on first scenario', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.login(PercChainConstants.treasuryUsername, 'password123');

    final result = ledger.creditScenario(
      username: PercChainConstants.treasuryUsername,
      percentChance: 25,
    );
    expect(result.status, PercFaucetCreditStatus.credited);
    expect(result.reward!.base.displayFixed8, '0.00000050');
  });

  test('faucet draw blocked for 450 minutes per wallet', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    final first = ledger.creditScenario(username: 'alice', percentChance: 10);
    expect(first.status, PercFaucetCreditStatus.credited);

    final second = ledger.creditScenario(username: 'alice', percentChance: 20);
    expect(second.status, PercFaucetCreditStatus.onCooldown);
    expect(second.cooldownRemaining, isNotNull);
    expect(second.cooldownRemaining!.inMinutes, greaterThan(440));
    expect(ledger.account('alice')!.balance, first.reward!.total);
  });

  test('send transfers PERC between local accounts', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'alice', percentChance: 50);
    final sent = ledger.send(
      fromUsername: 'alice',
      toUsername: 'bob',
      amount: PercAmount.fromPerc(0.00000010),
    );

    expect(sent.kind.name, 'transfer');
    expect(ledger.account('bob')!.balance.microUnits, greaterThan(0));
    expect(ledger.blocks.length, greaterThanOrEqualTo(2));
  });

  test('treasury username is rgsneddon', () {
    expect(PercChainConstants.treasuryUsername, 'rgsneddon');
  });

  test('wallet provider persists ledger across reload', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('carol', 'password12345');
    final credited = await wallet.creditScenario(percentChance: 55, memo: 'Persist');
    expect(credited?.status, PercFaucetCreditStatus.credited);
    final balance = wallet.balance.microUnits;

    final wallet2 = PercWalletProvider(store: store);
    await wallet2.initialize();
    await wallet2.login('carol', 'password12345');
    expect(wallet2.balance.microUnits, balance);
  });
}