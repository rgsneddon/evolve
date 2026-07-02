import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/models/perc_dapp_spec.dart';
import 'package:evolve/perc/models/perc_side_chain.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.login(PercChainConstants.treasuryUsername, 'password123');
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  setUp(() => PercLedgerHub.resetForTest());

  test('beam suite has send/receive, side chain, bridge, and mesh dapps', () {
    final kinds = PercDappSpec.beamSuite.map((d) => d.kind).toSet();
    expect(kinds, contains(PercDappKind.sendReceive));
    expect(kinds, contains(PercDappKind.sideChain));
    expect(kinds, contains(PercDappKind.sideChainBridge));
    expect(kinds, contains(PercDappKind.meshBridge));
    expect(PercDappSpec.beamSuite.length, greaterThanOrEqualTo(8));
  });

  test('side chain parents main chain and tracks microblocks', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.connectAllWalletsConcurrently();
    ledger.recordMicroblock(input: const ScenarioInput(posedQuestion: 'test'));

    final side = PercSideChainState.fromLedger(ledger);
    expect(side.parentChainId, PercChainConstants.chainId);
    expect(side.sideChainId, PercChainConstants.sideChainId);
    expect(side.microblockHeight, 1);
  });

  test('all registered users can receive; non-treasury can send', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('peer1', 'password12345');
    await wallet.register('peer2', 'password12345');

    await wallet.login('peer1', 'password12345');
    expect(wallet.canReceiveFromSession, isTrue);
    expect(wallet.canSendFromSession, isTrue);
    expect(wallet.sendablePeers, isNotEmpty);

    await wallet.login(PercChainConstants.treasuryUsername, 'password12345');
    expect(wallet.canReceiveFromSession, isTrue);
    expect(wallet.canSendFromSession, isFalse);
  });
}