import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_app_version.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_chain_evolution.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() => PercLedgerHub.resetForTest());

  test('evolveLedger anchors chain to Chronoflux Principia without resetting blocks', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password123');
    ledger.login(PercChainConstants.treasuryUsername, 'password123');
    ledger.consumeBlockchainLaunchEvent();
    ledger.register('alice', 'password123');
    final heightBefore = ledger.blockHeight;

    const evolution = PercChainEvolution();
    expect(evolution.evolveLedger(ledger, appVersion: '1.2.0+1'), isTrue);
    expect(ledger.evolutionaryChainId, PercChainConstants.evolutionaryChainId);
    expect(ledger.chronofluxPrincipiaId, PercChainConstants.chronofluxPrincipiaId);
    expect(ledger.evolvedAppVersions, contains('1.2.0+1'));
    expect(ledger.evolutionSteps, isNotEmpty);
    expect(ledger.blockHeight, heightBefore);

    expect(evolution.evolveLedger(ledger, appVersion: '1.2.0+1'), isFalse);
    expect(evolution.evolveLedger(ledger, appVersion: PercAppVersion.current), isTrue);
    expect(ledger.evolvedAppVersions.length, 2);
  });

  test('ledger json round-trip preserves evolutionary chain across versions', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    const PercChainEvolution().evolveLedger(ledger, appVersion: '1.2.4+30');

    final restored = PercLedger.fromJson(ledger.toJson());
    expect(restored.evolutionaryChainId, PercChainConstants.evolutionaryChainId);
    expect(restored.evolvedAppVersions, contains('1.2.4+30'));
    expect(restored.toJson()['version'], 6);
  });

  test('hub connects current app version to same evolutionary chain', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();

    expect(wallet.isOnEvolutionaryChain, isTrue);
    expect(wallet.evolvedAppVersions, contains(PercAppVersion.current));
    expect(wallet.evolutionaryChainId, PercChainConstants.evolutionaryChainId);
  });
}