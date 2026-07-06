import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  test('resetFromSeedLedger resets local chain to block 0', () {
    final local = PercLedger.empty();
    local.ensureTreasuryAccount();
    local.setupTreasuryPassword('password12345');
    local.launchBlockchain();
    local.register('alice', 'password12345');
    local.creditScenario(
      username: 'alice',
      percentChance: 50,
      scenarioLabel: 'before reset',
    );
    expect(local.blockHeight, greaterThan(0));

    final seed = PercLedger.fromJson(local.toJson());
    seed.blocks.clear();
    seed.accounts.clear();
    seed.ensureTreasuryAccount();
    seed.blockchainLaunched = false;
    seed.treasuryGenesisDone = false;
    seed.networkGenesisRevision = 2;
    seed.walletPeers.clear();
    seed.connectAllWalletsConcurrently();

    local.resetFromSeedLedger(seed, expectedTipHash: PercChainTip.hash(seed));

    expect(local.blockHeight, 0);
    expect(local.networkGenesisRevision, 2);
    expect(local.accounts.containsKey('alice'), isFalse);
    expect(local.accounts.containsKey(PercChainConstants.treasuryUsername), isTrue);
  });
}