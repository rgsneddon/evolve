import 'dart:io';

import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_chain_alignment.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

const _scratch =
    r'C:\Users\rgsne\AppData\Local\Temp\grok-goal-cfe4cc6e1bad\implementer';

void _writeLog(String filename, String body) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch${Platform.pathSeparator}$filename').writeAsStringSync(body);
}

PercLedger _tallSeedLedger({int extraBlocks = 4}) {
  final seed = PercLedger.empty();
  seed.ensureTreasuryAccount();
  seed.setupTreasuryPassword('password12345');
  seed.launchBlockchain();
  seed.consumeBlockchainLaunchEvent();
  for (var i = 0; i < extraBlocks; i++) {
    seed.blocks.add(
      PercBlock(
        index: seed.blocks.length,
        timestamp: DateTime.utc(2026, 3, 1, 12, i),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'canonical seed $i',
      ),
    );
  }
  return seed;
}

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    PercNetworkCoordinator.instance.clearTestSeedLedger();
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('registration adopts seed chain height tip and chain id', () async {
    final seed = _tallSeedLedger();
    PercNetworkCoordinator.instance.registerTestSeedLedger(seed);

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('chainuser', 'password12345');

    final ledger = PercLedgerHub.instance.ledger;
    final afterHeight = ledger.blockHeight;
    final afterTip = PercChainTip.hash(ledger);
    final afterChainId = PercChainAlignment.effectiveChainId(ledger);

    _writeLog(
      'registration_chain_alignment.log',
      'username=chainuser\n'
      'beforeHeight=0\n'
      'afterHeight=$afterHeight\n'
      'seedHeight=${PercChainTip.height(seed)}\n'
      'afterTip=$afterTip\n'
      'seedTip=${PercChainTip.hash(seed)}\n'
      'afterChainId=$afterChainId\n'
      'seedChainId=${PercChainAlignment.effectiveChainId(seed)}\n',
    );

    expect(afterChainId, PercChainAlignment.effectiveChainId(seed));
    expect(afterHeight, PercChainTip.height(seed));
    expect(afterTip, PercChainTip.hash(seed));
    expect(ledger.account('chainuser'), isNotNull);
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.registrationAwaitingSeedAlignment, isFalse);
    expect(wallet.isNetworkSynced, isTrue);
  });

  test('second hub session sees registered user on adopted chain', () async {
    final seed = _tallSeedLedger(extraBlocks: 5);
    PercNetworkCoordinator.instance.registerTestSeedLedger(seed);
    final store = PercWalletStoreMemory();

    final walletA = PercWalletProvider(store: store);
    final walletB = PercWalletProvider(store: store);
    await walletA.initialize();
    await walletB.initialize();
    await walletA.setupTreasuryPassword('password12345');
    await walletA.register('shareduser', 'password12345');

    final addr = walletA.address;
    final resolved = PercLedgerHub.instance.ledger.accountForAddress(addr);

    _writeLog(
      'cross_wallet_registration_chain.log',
      'sessionAHeight=${walletA.blockHeight}\n'
      'sessionBHeight=${walletB.blockHeight}\n'
      'sessionATip=${PercChainTip.hash(PercLedgerHub.instance.ledger)}\n'
      'seedTip=${PercChainTip.hash(seed)}\n'
      'address=$addr\n'
      'resolvedUsername=${resolved?.username}\n',
    );

    expect(walletB.blockHeight, walletA.blockHeight);
    expect(walletB.networkBlockHeight, walletA.networkBlockHeight);
    expect(
      PercChainTip.hash(PercLedgerHub.instance.ledger),
      PercChainTip.hash(seed),
    );
    expect(resolved?.username, 'shareduser');
  });

  test('registration with unreachable seed allows connect with offline status', () async {
    PercNetworkCoordinator.instance.testSeedReachable = false;

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('offlineuser', 'password12345');

    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.registrationAwaitingSeedAlignment, isFalse);
    expect(wallet.isConnectedToSeed, isFalse);
    expect(wallet.statusMessage, 'wallet_sync_seed_offline');
  });

  test('aligned registration publishes only after adopt import completes', () async {
    final seed = _tallSeedLedger();
    PercNetworkCoordinator.instance.registerTestSeedLedger(seed);

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('pathuser', 'password12345');

    final published = wallet.onlineNetworkNodes
        .any((n) => n.username == 'pathuser' && n.online);

    _writeLog(
      'registration_sync_path.log',
      'flow=adopt_then_publish\n'
      'alignedHeight=${wallet.blockHeight}\n'
      'seedHeight=${PercChainTip.height(seed)}\n'
      'tipsMatch=${PercChainTip.hash(PercLedgerHub.instance.ledger) == PercChainTip.hash(seed)}\n'
      'publishedOnline=$published\n'
      'walletConnectComplete=${wallet.isWalletConnectComplete}\n',
    );

    expect(wallet.blockHeight, PercChainTip.height(seed));
    expect(
      PercChainTip.hash(PercLedgerHub.instance.ledger),
      PercChainTip.hash(seed),
    );
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(published, isTrue);
  });
}