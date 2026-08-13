import 'package:evolve/perc/models/perc_account.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rematerializeTreasuryFromEmissionTargets funds evolve_treasury for faucet',
      () {
    final salt = PercAuth.generateSalt();
    final ledger = PercLedger.empty()
      ..blockchainLaunched = true
      ..treasuryGenesisDone = true
      ..networkGenesisRevision = 2
      ..evolutionaryChainId = PercChainConstants.evolutionaryChainId;

    // Simulated public import: treasury only under alias with huge balance.
    final alias = '3yqC7';
    ledger.accounts[alias] = PercAccount(
      username: alias,
      passwordHash: '',
      salt: salt,
      address: PercAuth.deriveAddress(alias, salt),
      passwordSet: false,
      balance: PercAmount.fromPerc(100000),
    );
    // Remove empty default treasury if empty() created one
    ledger.accounts.remove(PercChainConstants.treasuryUsername);

    final now = DateTime.utc(2026, 8, 1);
    ledger.blocks.add(
      PercBlock(
        index: 0,
        timestamp: now,
        transactions: [
          PercTransaction(
            id: 'tx-e1',
            kind: PercTxKind.treasuryEmission,
            amount: PercAmount.fromPerc(1000),
            timestamp: now,
            toUsername: alias,
          ),
        ],
        treasuryEmitted: PercAmount.fromPerc(1000),
      ),
    );

    ledger.rematerializeTreasuryFromEmissionTargets();
    expect(ledger.accounts.containsKey(PercChainConstants.treasuryUsername), isTrue);
    expect(
      ledger.accounts[PercChainConstants.treasuryUsername]!.balance.microUnits,
      greaterThan(0),
    );
    expect(ledger.accounts.containsKey(alias), isFalse);

    // User account can receive scenario reward
    final userSalt = PercAuth.generateSalt();
    const user = 'alice';
    ledger.accounts[user] = PercAccount(
      username: user,
      passwordHash: PercAuth.hashPassword('password12345', userSalt),
      salt: userSalt,
      address: PercAuth.deriveAddress(user, userSalt),
      passwordSet: true,
    );
    ledger.sessionUsername = user;

    final result = ledger.creditScenario(
      username: user,
      percentChance: 56.4,
      scenarioLabel: 'Percent chance: test reward',
    );
    expect(result.status.toString(), contains('credited'),
        reason: 'got ${result.status}');
    expect(result.reward, isNotNull);
    expect(result.reward!.total.microUnits, greaterThan(0));
    expect(ledger.accounts[user]!.balance.microUnits, greaterThan(0));
  });
}
