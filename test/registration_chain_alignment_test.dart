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

Future<PercWalletProvider> _openSecondSessionFromStore(
  PercWalletStoreMemory sourceStore,
) async {
  final snapshot = PercLedger.fromJson(
    (await sourceStore.load())!.toJson(),
  );
  final secondStore = PercWalletStoreMemory();
  await secondStore.save(snapshot);
  final wallet = PercWalletProvider(store: secondStore);
  await wallet.initialize();
  return wallet;
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

  test('second session on persisted store resolves registered user', () async {
    final seed = _tallSeedLedger(extraBlocks: 5);
    PercNetworkCoordinator.instance.registerTestSeedLedger(seed);
    final storeA = PercWalletStoreMemory();

    final walletA = PercWalletProvider(store: storeA);
    await walletA.initialize();
    await walletA.setupTreasuryPassword('password12345');
    await walletA.register('shareduser', 'password12345');
    await PercLedgerHub.instance.persistLocal();

    final walletB = await _openSecondSessionFromStore(storeA);
    final addr = walletA.address;
    final networkResolved =
        await PercLedgerHub.instance.network.resolveAccountByAddress(addr);

    _writeLog(
      'cross_wallet_registration_chain.log',
      'sessionAHeight=${walletA.blockHeight}\n'
      'sessionBHeight=${walletB.blockHeight}\n'
      'sessionATip=${PercChainTip.hash(PercLedgerHub.instance.ledger)}\n'
      'seedTip=${PercChainTip.hash(seed)}\n'
      'address=$addr\n'
      'networkResolvedUsername=${networkResolved?.username}\n'
      'pendingRecovery=${PercNetworkCoordinator.instance.hasPendingRegistrationRecovery}\n',
    );

    expect(walletB.blockHeight, PercChainTip.height(seed));
    expect(walletB.networkBlockHeight, walletA.networkBlockHeight);
    expect(
      PercChainTip.hash(PercLedgerHub.instance.ledger),
      PercChainTip.hash(seed),
    );
    expect(networkResolved?.username, 'shareduser');
    expect(
      PercNetworkCoordinator.instance.hasPendingRegistrationRecovery,
      isFalse,
    );
  });

  test('registration with unreachable seed allows connect with offline status', () async {
    final seed = _tallSeedLedger();
    PercNetworkCoordinator.instance.registerTestSeedLedger(seed);
    PercNetworkCoordinator.instance.testSeedReachable = false;

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('offlineuser', 'password12345');
    await PercNetworkCoordinator.instance.awaitDeepSyncIdle();

    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.registrationAwaitingSeedAlignment, isFalse);
    expect(wallet.isConnectedToSeed, isFalse);
    expect(wallet.statusMessage, 'wallet_sync_seed_offline');
    expect(
      PercNetworkCoordinator.instance.hasPendingRegistrationRecovery,
      isTrue,
    );
    expect(
      PercNetworkCoordinator.instance.activeUsernameForTest,
      'offlineuser',
    );
    expect(
      PercChainTip.height(PercLedgerHub.instance.ledger),
      lessThan(PercChainTip.height(seed)),
    );
  });

  test(
    'offline registration recovers via background deep sync when seed returns',
    () async {
      final seed = _tallSeedLedger();
      PercNetworkCoordinator.instance.registerTestSeedLedger(seed);
      PercNetworkCoordinator.instance.testSeedReachable = false;

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.register('bgoffline', 'password12345');
      await PercNetworkCoordinator.instance.awaitDeepSyncIdle();

      expect(
        PercNetworkCoordinator.instance.hasPendingRegistrationRecovery,
        isTrue,
      );

      PercNetworkCoordinator.instance.testSeedReachable = true;
      PercNetworkCoordinator.instance.scheduleDeepSync();
      await PercNetworkCoordinator.instance.awaitDeepSyncIdle();

      final ledger = PercLedgerHub.instance.ledger;
      final published = wallet.onlineNetworkNodes
          .any((n) => n.username == 'bgoffline' && n.online);

      _writeLog(
        'registration_recovery_after_sync.log',
        'path=background_scheduleDeepSync\n'
        'username=bgoffline\n'
        'afterHeight=${ledger.blockHeight}\n'
        'seedHeight=${PercChainTip.height(seed)}\n'
        'afterTip=${PercChainTip.hash(ledger)}\n'
        'seedTip=${PercChainTip.hash(seed)}\n'
        'publishedOnline=$published\n'
        'pendingRecovery=${PercNetworkCoordinator.instance.hasPendingRegistrationRecovery}\n',
      );

      expect(ledger.blockHeight, PercChainTip.height(seed));
      expect(PercChainTip.hash(ledger), PercChainTip.hash(seed));
      expect(ledger.account('bgoffline'), isNotNull);
      expect(published, isTrue);
      expect(
        PercNetworkCoordinator.instance.hasPendingRegistrationRecovery,
        isFalse,
      );
    },
  );

  test('offline registration recovers account after genesis reset on sync', () async {
    final seed = _tallSeedLedger();
    seed.networkGenesisRevision = 2;
    PercNetworkCoordinator.instance.registerTestSeedLedger(seed);
    PercNetworkCoordinator.instance.testSeedReachable = false;

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    expect(PercLedgerHub.instance.ledger.networkGenesisRevision, 1);

    await wallet.register('offlinegen', 'password12345');

    expect(wallet.statusMessage, 'wallet_sync_seed_offline');
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(
      PercNetworkCoordinator.instance.hasPendingRegistrationRecovery,
      isTrue,
    );

    PercNetworkCoordinator.instance.testSeedReachable = true;
    await wallet.syncWalletToSeed();

    final ledger = PercLedgerHub.instance.ledger;

    _writeLog(
      'registration_offline_genesis_recovery.log',
      'username=offlinegen\n'
      'localGenesisAfter=${ledger.networkGenesisRevision}\n'
      'afterHeight=${ledger.blockHeight}\n'
      'seedHeight=${PercChainTip.height(seed)}\n'
      'afterTip=${PercChainTip.hash(ledger)}\n'
      'seedTip=${PercChainTip.hash(seed)}\n'
      'accountPresent=${ledger.account('offlinegen') != null}\n',
    );

    expect(ledger.networkGenesisRevision, 2);
    expect(ledger.account('offlinegen'), isNotNull);
    expect(ledger.blockHeight, PercChainTip.height(seed));
    expect(PercChainTip.hash(ledger), PercChainTip.hash(seed));
    expect(wallet.hasAppAccess, isTrue);
    expect(
      PercNetworkCoordinator.instance.hasPendingRegistrationRecovery,
      isFalse,
    );
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