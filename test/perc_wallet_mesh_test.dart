import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';

void main() {
  setUp(() => PercLedgerHub.resetForTest());

  test('every wallet connects to every other wallet in full mesh', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');

    ledger.connectAllWalletsConcurrently();

    expect(ledger.isWalletMeshComplete, isTrue);
    expect(ledger.connectedPeersFor('alice'), ['bob', PercChainConstants.treasuryUsername]);
    expect(ledger.connectedPeersFor('bob'), ['alice', PercChainConstants.treasuryUsername]);
    expect(
      ledger.connectedPeersFor(PercChainConstants.treasuryUsername),
      ['alice', 'bob'],
    );
  });

  test('wallet mesh persists and reloads through ledger hub', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('dave', 'password12345');
    await wallet.register('erin', 'password12345');

    expect(wallet.isWalletMeshComplete, isTrue);
    expect(wallet.connectedWalletCount, 2);

    PercLedgerHub.resetForTest();
    final wallet2 = PercWalletProvider(store: store);
    await wallet2.initialize();
    await wallet2.login('dave', 'password12345');

    expect(wallet2.isWalletMeshComplete, isTrue);
    expect(wallet2.connectedPeerWallets, contains('erin'));
    expect(wallet2.connectedPeerWallets, contains(PercChainConstants.treasuryUsername));
  });

  test('hub shares ledger state across provider instances concurrently', () async {
    final store = PercWalletStoreMemory();
    final walletA = PercWalletProvider(store: store);
    final walletB = PercWalletProvider(store: store);
    await walletA.initialize();
    await walletB.initialize();

    await walletA.setupTreasuryPassword('password12345');
    await walletA.register('frank', 'password12345');

    expect(walletB.blockHeight, walletA.blockHeight);
    expect(walletB.isWalletMeshComplete, isTrue);
  });
}