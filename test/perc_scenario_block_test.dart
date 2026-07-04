import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('scenario conclusion advances user scenario block by 1', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password12345');

    expect(ledger.account('alice')!.scenarioBlockHeight, 0);

    ledger.creditScenario(
      username: 'alice',
      percentChance: 42,
      scenarioLabel: 'First scenario',
    );

    expect(ledger.account('alice')!.scenarioBlockHeight, 1);

    ledger.creditScenario(
      username: 'alice',
      percentChance: 55,
      scenarioLabel: 'Second scenario',
    );

    expect(ledger.account('alice')!.scenarioBlockHeight, 2);
  });

  test('cooldown scenario still advances scenario block', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('bob', 'password12345');

    final first = ledger.creditScenario(
      username: 'bob',
      percentChance: 30,
      scenarioLabel: 'Funded',
    );
    expect(first.status, PercFaucetCreditStatus.credited);
    expect(first.scenarioBlockHeight, 1);

    final second = ledger.creditScenario(
      username: 'bob',
      percentChance: 40,
      scenarioLabel: 'Cooldown',
    );
    expect(second.status, PercFaucetCreditStatus.onCooldown);
    expect(second.scenarioBlockHeight, 2);
  });

  test('scenario block respects 100M cap', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('cap', 'password12345');
    ledger.account('cap')!.scenarioBlockHeight =
        PercChainConstants.maxScenarioBlocksPerWallet;

    final next = ledger.advanceScenarioBlock('cap');
    expect(next, PercChainConstants.maxScenarioBlocksPerWallet);
    expect(ledger.account('cap')!.scenarioBlockHeight,
        PercChainConstants.maxScenarioBlocksPerWallet);
  });
}