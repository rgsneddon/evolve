import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_inflation.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/perc_chain_constants.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('critical pool threshold is 1 cent (0.00000001 PERC)', () {
    expect(
      PercInflation.criticalPoolThreshold,
      PercChainConstants.minimumTreasuryReserve,
    );
    expect(PercInflation.criticalPoolThreshold.displayFixed8, '0.00000001');
  });

  test('last inflation epoch follows treasury emission blocks', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    expect(ledger.lastInflationEpoch, isNull);

    ledger.creditScenario(username: 'alice', percentChance: 10);
    expect(ledger.lastInflationEpoch, isNotNull);
    expect(ledger.blocks.last.treasuryEmitted.isPositive, isTrue);
  });

  test('time to next inflation counts down from last epoch', () {
    final epoch = DateTime.utc(2026, 7, 2, 12, 0, 0);
    final now = epoch.add(const Duration(milliseconds: 400));

    final wait = PercInflation.timeToNextInflation(
      lastInflationEpoch: epoch,
      blockchainLaunched: true,
      treasuryCapped: false,
      treasuryPool: PercAmount.fromPerc(1),
      now: now,
    );

    expect(wait, const Duration(milliseconds: 59600));
  });

  test('treasury below 0.66 PERC triggers regeneration toward 1 PERC', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 10);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    treasury.balance = PercAmount.fromPerc(0.50);

    expect(ledger.treasuryNeedsRegeneration, isTrue);
    expect(ledger.timeToNextInflation(), Duration.zero);

    final result = ledger.creditScenario(username: 'alice', percentChance: 10);
    expect(result.status.name, 'onCooldown');
    expect(
      treasury.balance.microUnits,
      greaterThan(PercChainConstants.treasuryRegenerationThreshold.microUnits),
    );
    expect(
      treasury.transactions.any(
        (tx) => tx.memo?.contains('Treasury regeneration') ?? false,
      ),
      isTrue,
    );
  });

  test('critical treasury pool shows zero time to next inflation', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 10);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    treasury.balance = PercChainConstants.minimumTreasuryReserve;

    expect(ledger.treasuryPoolCritical, isTrue);
    expect(ledger.timeToNextInflation(), Duration.zero);
  });
}