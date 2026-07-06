import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  test('blockchain does not launch from local treasury login', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password123');
    ledger.register('alice', 'password123');

    expect(ledger.isBlockchainLaunched, isFalse);
    expect(ledger.blocks, isEmpty);

    final blocked = ledger.creditScenario(username: 'alice', percentChance: 10);
    expect(blocked.status, PercFaucetCreditStatus.blockchainNotLaunched);
    expect(ledger.blocks, isEmpty);

    ledger.login('alice', 'password123');
    expect(ledger.isBlockchainLaunched, isFalse);

    ledger.login(PercChainConstants.treasuryUsername, 'password123');
    expect(ledger.isBlockchainLaunched, isFalse);
    expect(ledger.consumeBlockchainLaunchEvent(), isFalse);
  });

  test('launchBlockchain is a one-time seed treasury action', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');

    ledger.launchBlockchain();
    expect(ledger.isBlockchainLaunched, isTrue);
    expect(ledger.consumeBlockchainLaunchEvent(), isTrue);
    expect(ledger.consumeBlockchainLaunchEvent(), isFalse);

    ledger.launchBlockchain();
    expect(ledger.consumeBlockchainLaunchEvent(), isFalse);
  });

  test('scenarios advance chain only after launch', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password123');
    ledger.register('bob', 'password123');
    ledger.launchBlockchain();
    ledger.consumeBlockchainLaunchEvent();

    ledger.login('bob', 'password123');
    final result = ledger.creditScenario(username: 'bob', percentChance: 25);
    expect(result.status, PercFaucetCreditStatus.credited);
    expect(ledger.blocks, isNotEmpty);
  });
}