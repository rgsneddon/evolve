import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_fly_client.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fly = PercFlyClient();

  PercLedger localWithBlocks() {
    final local = PercLedger.empty();
    local.ensureTreasuryAccount();
    local.setupTreasuryPassword('password12345');
    local.launchBlockchain();
    local.register('alice', 'password12345');
    local.creditScenario(
      username: 'alice',
      percentChance: 42,
      scenarioLabel: 'test',
    );
    return local;
  }

  PercNetworkStatus seedStatus({
    required int height,
    String tip = 'tip-a',
    int genesis = 1,
  }) {
    return PercNetworkStatus(
      evolutionaryChainId: PercChainConstants.evolutionaryChainId,
      blockHeight: height,
      tipHash: tip,
      revision: 1,
      networkGenesisRevision: genesis,
      sessionUsername: PercChainConstants.seedUsername,
      endpoint: 'https://seed.example/perc',
    );
  }

  test('needsFullLedger when local height is behind seed tip', () {
    final local = PercLedger.empty();
    expect(
      fly.needsFullLedger(
        local: local,
        seedStatus: seedStatus(height: 12),
        targetGenesis: 1,
      ),
      isTrue,
    );
  });

  test('skips full ledger when local tip already matches seed height', () {
    final local = localWithBlocks();
    final height = PercChainTip.height(local);
    final tip = PercChainTip.hash(local);
    expect(
      fly.needsFullLedger(
        local: local,
        seedStatus: seedStatus(height: height, tip: tip),
        targetGenesis: 1,
      ),
      isFalse,
    );
  });

  test('quick probe marks syncing when local is behind network height', () {
    final local = PercLedger.empty();
    expect(
      fly.syncStateAfterQuickProbe(
        local: local,
        networkHeight: 8,
      ),
      PercNetworkSyncState.syncing,
    );
  });

  test('quick probe marks synced when heights match', () {
    final local = localWithBlocks();
    final height = PercChainTip.height(local);
    expect(
      fly.syncStateAfterQuickProbe(
        local: local,
        networkHeight: height,
      ),
      PercNetworkSyncState.synced,
    );
  });
}