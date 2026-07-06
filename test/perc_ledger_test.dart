import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_account.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';

import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('first scenario mints launch allocation to evolve_treasury', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      scenarioLabel: 'Test',
    );

    expect(result.status, PercFaucetCreditStatus.credited);
    expect(
      ledger.cumulativeTreasuryMinted,
      PercChainConstants.treasuryLaunchAllocation,
    );
    expect(ledger.blocks.length, 1);
    expect(
      ledger.blocks.first.treasuryEmitted,
      PercChainConstants.treasuryLaunchAllocation,
    );
    expect(
      ledger.treasuryBalance,
      PercChainConstants.treasuryLaunchAllocation - result.reward!.total,
    );
  });

  test('scenario credit adds xx/100 PERC to user from percent outcome', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('bob', 'password123');

    final result = ledger.creditScenario(username: 'bob', percentChance: 42);
    expect(result.status, PercFaucetCreditStatus.credited);
    final bob = ledger.account('bob')!;
    expect(bob.balance, PercAmount.fromPerc(0.42));
    expect(result.reward!.outcomeFractionLabel, '42/100');
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
    expect(result.reward!.twoDigitOutcome, 25);
    expect(result.reward!.total, PercAmount.fromPerc(0.25));
  });

  test('faucet draw blocked for 7 minutes per wallet', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    final first = ledger.creditScenario(username: 'alice', percentChance: 10);
    expect(first.status, PercFaucetCreditStatus.credited);

    final second = ledger.creditScenario(username: 'alice', percentChance: 20);
    expect(second.status, PercFaucetCreditStatus.onCooldown);
    expect(second.cooldownRemaining, isNotNull);
    expect(second.cooldownRemaining!.inMinutes, greaterThanOrEqualTo(6));
    expect(ledger.account('alice')!.balance, first.reward!.total);
  });

  test('send queues PERC when recipient wallet is offline', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'alice', percentChance: 50);
    final sent = ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000010),
    );

    expect(sent.kind.wireName, 'transfer');
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.pendingInboundFor('bob'), hasLength(1));
    expect(ledger.blocks.length, greaterThanOrEqualTo(2));
  });

  test('send rejects usernames — PERC address required', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    expect(
      () => ledger.send(
        fromUsername: 'alice',
        toAddress: 'bob',
        amount: PercAmount.fromPerc(0.00000005),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('send credits recipient after scenario activity when their wallet is online', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    ledger.login('bob', 'password123');
    ledger.setWalletOnline(
      'bob',
      blockHeight: ledger.blockHeight,
      tipHash: PercChainTip.hash(ledger),
    );

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000005),
    );

    expect(ledger.pendingInboundFor('bob'), isEmpty);
    expect(
      ledger.account('bob')!.balance,
      PercAmount.fromPerc(0.00000005),
    );
  });

  test('treasury username is evolve_treasury', () {
    expect(PercChainConstants.treasuryUsername, 'evolve_treasury');
  });

  test('migrates legacy rgsneddon treasury to evolve_treasury', () {
    final ledger = PercLedger.empty();
    final salt = 'legacy-salt';
    ledger.accounts['rgsneddon'] = PercAccount(
      username: 'rgsneddon',
      passwordHash: 'hash',
      salt: salt,
      address: 'perc1legacy',
      passwordSet: true,
      balance: PercAmount.fromPerc(5),
    );
    ledger.sessionUsername = 'rgsneddon';
    ledger.blockchainLaunched = true;
    ledger.register('alice', 'password123');

    ledger.migrateLegacyTreasuryAccounts();

    expect(ledger.accounts.containsKey('rgsneddon'), isFalse);
    expect(ledger.account('evolve_treasury'), isNotNull);
    expect(ledger.account('evolve_treasury')!.balance, PercAmount.fromPerc(5));
    expect(ledger.sessionUsername, 'evolve_treasury');
    expect(ledger.account('rgsneddon'), isNull);
    expect(ledger.accounts.keys, isNot(contains('rgsneddon')));
  });

  test('aligned emission at reserve funds faucet without pool renewal', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 10);

    final alice = ledger.account('alice')!;
    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final elapsed = PercChainConstants.faucetCooldown;
    final past = DateTime.now().toUtc().subtract(elapsed);
    alice.lastFaucetDrawAt = past;
    treasury.balance = PercChainConstants.minimumTreasuryReserve;
    ledger.treasuryGenesisDone = true;
    ledger.lastScenarioAt = past;

    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      scenarioLabel: 'Aligned emission',
    );

    expect(result.status, PercFaucetCreditStatus.credited);
    expect(ledger.treasuryCycle, 1);
    expect(ledger.blocks.any((b) => b.isGenesisRenewal), isFalse);
    expect(
      treasury.balance.microUnits,
      greaterThan(PercChainConstants.minimumTreasuryReserve.microUnits),
    );
  });

  test('send at 1 cent treasury reserve does not create genesis renewal', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'alice', percentChance: 50);
    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    treasury.balance = PercChainConstants.minimumTreasuryReserve;

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000010),
    );

    expect(ledger.treasuryCycle, 1);
    expect(ledger.blocks.any((b) => b.isGenesisRenewal), isFalse);
  });

  test('wallet provider persists ledger across reload', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    PercLedgerHub.instance.ledger.launchBlockchain();
    await wallet.register('carol', 'password12345');
    final credited = await wallet.creditScenario(outcomeScore: 55, memo: 'Persist');
    expect(credited?.status, PercFaucetCreditStatus.credited);
    final balance = wallet.balance.microUnits;

    final wallet2 = PercWalletProvider(store: store);
    await wallet2.initialize();
    await wallet2.login('carol', 'password12345');
    expect(wallet2.balance.microUnits, balance);
  });
}