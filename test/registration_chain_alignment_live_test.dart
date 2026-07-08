import 'dart:convert';
import 'dart:io';

import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_chain_alignment.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_account_privacy.dart';
import 'package:evolve/perc/services/perc_network_config.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

final _scratch = Platform.environment['SCRATCH'] ??
    r'C:\Users\rgsne\AppData\Local\Temp\grok-goal-cb031749c6db\implementer';

void _writeLog(String filename, String body) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch${Platform.pathSeparator}$filename').writeAsStringSync(body);
}

PercLedger _tallSeedLedger({int extraBlocks = 4}) {
  final seed = PercLedger.empty();
  seed.ensureTreasuryAccount();
  seed.setupTreasuryPassword('password12345');
  seed.networkGenesisRevision = 2;
  seed.launchBlockchain();
  seed.consumeBlockchainLaunchEvent();
  for (var i = 0; i < extraBlocks; i++) {
    seed.blocks.add(
      PercBlock(
        index: seed.blocks.length,
        timestamp: DateTime.utc(2026, 3, 1, 12, i),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'live seed $i',
      ),
    );
  }
  return seed;
}

void main() {
  HttpServer? server;
  late PercLedger mockSeedLedger;
  var rendezvousRegisterCount = 0;
  final registeredUsernames = <String>{};
  var serveSeedLedger = true;
  var serveSeedStatus = true;
  var serveSanitizedLedger = false;
  String? statusTipOverride;
  String? base;

  setUp(() async {
    PercLedgerHub.resetForTest();
    PercNetworkConfig.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    rendezvousRegisterCount = 0;
    registeredUsernames.clear();
    serveSeedLedger = true;
    serveSeedStatus = true;
    serveSanitizedLedger = false;
    statusTipOverride = null;
    mockSeedLedger = _tallSeedLedger();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server!.port}';

    final rendezvousBase = base!;
    PercNetworkConfig.setCachedForTest(
      PercNetworkConfig(
        rendezvousUrl: rendezvousBase,
        seedUsername: PercChainConstants.seedUsername,
        networkGenesisRevision: 2,
        publicEndpointOverride: rendezvousBase,
        publicIpLookupUrls: const [],
      ),
    );

    server!.listen((request) async {
      final path = request.uri.path;

      if (request.method == 'POST' && path == '/perc/rendezvous/register') {
        try {
          final body = await utf8.decoder.bind(request).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final session = json['sessionUsername'] as String?;
          if (session != null && session.isNotEmpty) {
            registeredUsernames.add(session);
          }
        } catch (_) {}
        rendezvousRegisterCount++;
        request.response
          ..statusCode = 200
          ..write('{"ok":true}')
          ..close();
        return;
      }

      if (request.method == 'POST' &&
          (path == '/perc/rendezvous/address' || path == '/perc/ledger')) {
        request.response
          ..statusCode = 200
          ..write('{"ok":true}')
          ..close();
        return;
      }

      if (request.method == 'GET' && path == '/perc/status') {
        if (!serveSeedStatus) {
          request.response
            ..statusCode = 404
            ..close();
          return;
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'evolutionaryChainId': PercChainConstants.evolutionaryChainId,
              'blockHeight': mockSeedLedger.blockHeight,
              'tipHash': statusTipOverride ?? PercChainTip.hash(mockSeedLedger),
              'revision': 1,
              'networkGenesisRevision': 2,
              'sessionUsername': PercChainConstants.seedUsername,
              'endpoint': base,
            }),
          )
          ..close();
        return;
      }

      if (request.method == 'GET' && path == '/perc/ledger') {
        if (!serveSeedLedger) {
          request.response
            ..statusCode = 404
            ..close();
          return;
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(
              serveSanitizedLedger
                  ? PercAccountPrivacy.sanitizeLedgerForPublic(
                      mockSeedLedger.toJson(),
                    )
                  : mockSeedLedger.toJson(),
            ),
          )
          ..close();
        return;
      }

      if (request.method == 'GET' && path == '/perc/rendezvous/peers') {
        request.response
          ..statusCode = 200
          ..write('[]')
          ..close();
        return;
      }

      if (request.method == 'GET' && path == '/perc/rendezvous/online') {
        request.response
          ..statusCode = 200
          ..write('{"online":false}')
          ..close();
        return;
      }

      request.response
        ..statusCode = 404
        ..close();
    });
  });

  tearDown(() async {
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    await server?.close(force: true);
    server = null;
    PercNetworkConfig.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('live HTTP registration adopts seed via fetch and import', () async {
    PercNetworkCoordinator.disableLiveNodesForTests = false;

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    PercLedgerHub.instance.ledger.networkGenesisRevision = 2;
    await wallet.register('liveuser', 'password12345');

    final ledger = PercLedgerHub.instance.ledger;
    final afterHeight = ledger.blockHeight;
    final afterTip = PercChainTip.hash(ledger);

    _writeLog(
      'registration_chain_alignment_live.log',
      'path=live_http\n'
      'username=liveuser\n'
      'afterHeight=$afterHeight\n'
      'seedHeight=${PercChainTip.height(mockSeedLedger)}\n'
      'afterTip=$afterTip\n'
      'seedTip=${PercChainTip.hash(mockSeedLedger)}\n'
      'rendezvousRegisterCount=$rendezvousRegisterCount\n',
    );

    expect(afterHeight, PercChainTip.height(mockSeedLedger));
    expect(afterTip, PercChainTip.hash(mockSeedLedger));
    expect(
      PercChainAlignment.effectiveChainId(ledger),
      PercChainAlignment.effectiveChainId(mockSeedLedger),
    );
    expect(ledger.account('liveuser'), isNotNull);
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.registrationAwaitingSeedAlignment, isFalse);
    expect(rendezvousRegisterCount, greaterThan(0));
  });

  test('live registration blocks publish when seed ledger fetch fails', () async {
    serveSeedLedger = false;
    PercNetworkCoordinator.disableLiveNodesForTests = false;

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    PercLedgerHub.instance.ledger.networkGenesisRevision = 2;

    rendezvousRegisterCount = 0;
    await wallet.register('blockeduser', 'password12345');

    _writeLog(
      'registration_publish_gate.log',
      'username=blockeduser\n'
      'walletConnectComplete=${wallet.isWalletConnectComplete}\n'
      'awaitingAlignment=${wallet.registrationAwaitingSeedAlignment}\n'
      'localHeight=${wallet.blockHeight}\n'
      'seedHeight=${mockSeedLedger.blockHeight}\n'
      'rendezvousRegisterCount=$rendezvousRegisterCount\n',
    );

    expect(wallet.registrationAwaitingSeedAlignment, isTrue);
    expect(wallet.isWalletConnectComplete, isFalse);
    expect(rendezvousRegisterCount, 0);

    serveSeedLedger = true;
    await wallet.syncWalletToSeed();

    final ledger = PercLedgerHub.instance.ledger;
    final afterHeight = ledger.blockHeight;
    final afterTip = PercChainTip.hash(ledger);

    _writeLog(
      'registration_recovery_after_sync.log',
      'username=blockeduser\n'
      'afterHeight=$afterHeight\n'
      'seedHeight=${PercChainTip.height(mockSeedLedger)}\n'
      'afterTip=$afterTip\n'
      'seedTip=${PercChainTip.hash(mockSeedLedger)}\n'
      'accountPresent=${ledger.account('blockeduser') != null}\n'
      'rendezvousRegisterCount=$rendezvousRegisterCount\n',
    );

    expect(ledger.account('blockeduser'), isNotNull);
    expect(afterHeight, PercChainTip.height(mockSeedLedger));
    expect(afterTip, PercChainTip.hash(mockSeedLedger));
    expect(wallet.registrationAwaitingSeedAlignment, isFalse);
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.hasAppAccess, isTrue);
    expect(rendezvousRegisterCount, greaterThan(0));
  });

  test('live deferred sync survives genesis reset and keeps new account', () async {
    serveSeedLedger = false;
    PercNetworkCoordinator.disableLiveNodesForTests = false;

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    // Leave local genesis at 1 — seed mock uses genesis 2 (reset path).
    expect(PercLedgerHub.instance.ledger.networkGenesisRevision, 1);

    await wallet.register('resetuser', 'password12345');
    expect(wallet.registrationAwaitingSeedAlignment, isTrue);
    expect(wallet.isWalletConnectComplete, isFalse);

    serveSeedLedger = true;
    await wallet.syncWalletToSeed();

    final ledger = PercLedgerHub.instance.ledger;

    _writeLog(
      'registration_genesis_reset_recovery.log',
      'username=resetuser\n'
      'localGenesisAfter=${ledger.networkGenesisRevision}\n'
      'afterHeight=${ledger.blockHeight}\n'
      'seedHeight=${PercChainTip.height(mockSeedLedger)}\n'
      'afterTip=${PercChainTip.hash(ledger)}\n'
      'seedTip=${PercChainTip.hash(mockSeedLedger)}\n'
      'accountPresent=${ledger.account('resetuser') != null}\n',
    );

    expect(ledger.networkGenesisRevision, 2);
    expect(ledger.account('resetuser'), isNotNull);
    expect(ledger.blockHeight, PercChainTip.height(mockSeedLedger));
    expect(
      PercChainTip.hash(ledger),
      PercChainTip.hash(mockSeedLedger),
    );
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.hasAppAccess, isTrue);
  });

  test(
    'sanitized fetch path aligns and publishes despite stale status tip',
    () async {
      serveSanitizedLedger = true;
      statusTipOverride =
          'stale-status-tip-00000000000000000000000000000000000000';
      PercNetworkCoordinator.disableLiveNodesForTests = false;

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      PercLedgerHub.instance.ledger.networkGenesisRevision = 2;

      rendezvousRegisterCount = 0;
      await wallet.register('sanitizedfetch', 'password12345');

      final hub = PercLedgerHub.instance;
      final coordinator = PercNetworkCoordinator.instance;
      final ledger = hub.ledger;
      final seedNode = ledger.networkNodes[PercChainConstants.seedUsername];
      final clientLedgerTip = PercChainTip.hash(ledger);
      final ledgerAligned = PercChainAlignment.isAlignedWithSeed(
        local: ledger,
        seedChainId: PercChainAlignment.effectiveChainId(mockSeedLedger),
        seedHeight: PercChainTip.height(mockSeedLedger),
        seedTipHash: PercChainTip.hash(mockSeedLedger),
      );

      _writeLog(
        'sanitized_fetch_alignment.log',
        'path=_fetchAndApplyCanonicalSeed\n'
        'username=sanitizedfetch\n'
        'statusTipOverride=$statusTipOverride\n'
        'seedNodeTip=${seedNode?.tipHash}\n'
        'clientLedgerTip=$clientLedgerTip\n'
        'canonicalTip=${PercChainTip.hash(mockSeedLedger)}\n'
        'ledgerAligned=$ledgerAligned\n'
        'pendingRecoveryCleared=${!coordinator.hasPendingRegistrationRecovery}\n'
        'height=${ledger.blockHeight}\n'
        'seedHeight=${PercChainTip.height(mockSeedLedger)}\n'
        'rendezvousRegisterCount=$rendezvousRegisterCount\n'
        'note=alignment gate uses imported ledger tip; stale status tip ignored\n',
      );

      expect(statusTipOverride, isNot(clientLedgerTip));
      expect(seedNode?.tipHash, clientLedgerTip);
      expect(seedNode?.tipHash, PercChainTip.hash(mockSeedLedger));
      expect(coordinator.hasPendingRegistrationRecovery, isFalse);
      expect(ledgerAligned, isTrue);
      expect(ledger.blockHeight, PercChainTip.height(mockSeedLedger));
      expect(clientLedgerTip, PercChainTip.hash(mockSeedLedger));
      expect(ledger.account('sanitizedfetch'), isNotNull);
      expect(wallet.isWalletConnectComplete, isTrue);
      expect(wallet.registrationAwaitingSeedAlignment, isFalse);
      expect(rendezvousRegisterCount, greaterThan(0));
    },
  );

  test('live offline registration recovers after genesis reset on sync', () async {
    serveSeedStatus = false;
    serveSeedLedger = false;
    PercNetworkCoordinator.disableLiveNodesForTests = false;

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    await wallet.initialize();
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    final hub = PercLedgerHub.instance;
    hub.ledger.ensureTreasuryAccount();
    hub.ledger.setupTreasuryPassword('password12345');
    expect(hub.ledger.networkGenesisRevision, 1);

    rendezvousRegisterCount = 0;
    await wallet.register('liveoffline', 'password12345');

    expect(wallet.statusMessage, 'wallet_sync_seed_offline');
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(
      PercNetworkCoordinator.instance.hasPendingRegistrationRecovery,
      isTrue,
    );
    expect(registeredUsernames.contains('liveoffline'), isFalse);

    serveSeedStatus = true;
    serveSeedLedger = true;
    await wallet.syncWalletToSeed();

    final ledger = PercLedgerHub.instance.ledger;

    _writeLog(
      'registration_offline_genesis_recovery.log',
      'path=live_http\n'
      'username=liveoffline\n'
      'localGenesisAfter=${ledger.networkGenesisRevision}\n'
      'afterHeight=${ledger.blockHeight}\n'
      'seedHeight=${PercChainTip.height(mockSeedLedger)}\n'
      'afterTip=${PercChainTip.hash(ledger)}\n'
      'seedTip=${PercChainTip.hash(mockSeedLedger)}\n'
      'accountPresent=${ledger.account('liveoffline') != null}\n'
      'rendezvousRegisterCount=$rendezvousRegisterCount\n',
    );

    expect(ledger.networkGenesisRevision, 2);
    expect(ledger.account('liveoffline'), isNotNull);
    expect(ledger.blockHeight, PercChainTip.height(mockSeedLedger));
    expect(
      PercChainTip.hash(ledger),
      PercChainTip.hash(mockSeedLedger),
    );
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.hasAppAccess, isTrue);
    expect(registeredUsernames.contains('liveoffline'), isTrue);
    expect(rendezvousRegisterCount, greaterThan(0));
  });
}