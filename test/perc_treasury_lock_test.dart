import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
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
  test('pool renewal allocation is 283 million PERC', () {
    expect(
      PercChainConstants.poolRenewalAllocation,
      PercAmount.fromPerc(283000000),
    );
    expect(PercChainConstants.infiniteContinuumSupply, isTrue);
    expect(PercChainConstants.confirmationsRequired, 1);
    expect(PercChainConstants.minimumTreasuryReserve.displayFixed8, '0.00000001');
  });

  test('treasury evolve_treasury cannot send manually after blockchain launch', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'bob', percentChance: 10);

    expect(ledger.isTreasurySendLocked, isTrue);

    expect(
      () => ledger.send(
        fromUsername: PercChainConstants.treasuryUsername,
        toAddress: _addr(ledger, 'bob'),
        amount: PercAmount.fromPerc(0.00000010),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('staking stops at 1 cent treasury reserve', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('staker', 'password123');
    ledger.register('runner', 'password123');
    ledger.creditScenario(username: 'staker', percentChance: 10);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    treasury.balance = PercChainConstants.minimumTreasuryReserve +
        PercStaking.rewardPerBlock;

    ledger.send(
      fromUsername: 'staker',
      toAddress: _addr(ledger, 'runner'),
      amount: PercAmount(1),
    );

    expect(
      treasury.balance,
      PercChainConstants.minimumTreasuryReserve,
    );
  });

  test('treasury pool renews with 283M mint at 1 cent reserve', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    treasury.balance = PercChainConstants.minimumTreasuryReserve;

    ledger.creditScenario(username: 'alice', percentChance: 25);

    expect(ledger.treasuryCycle, 2);
    expect(
      treasury.balance.microUnits,
      greaterThan(PercChainConstants.poolRenewalAllocation.microUnits),
    );
    expect(ledger.blocks.any((b) => b.isGenesisRenewal), isTrue);
  });

  test('transactions are fully confirmed with one block', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 10);

    final block = ledger.blocks.last;
    expect(block.isConfirmed, isTrue);
    expect(block.confirmations, 1);
    expect(
      block.transactions.every((t) => t.isConfirmed),
      isTrue,
    );
  });
}