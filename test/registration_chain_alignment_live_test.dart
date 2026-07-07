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
import 'package:evolve/perc/services/perc_network_config.dart';
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
  var serveSeedLedger = true;
  String? base;

  setUp(() async {
    PercLedgerHub.resetForTest();
    PercNetworkConfig.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    rendezvousRegisterCount = 0;
    serveSeedLedger = true;
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
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'evolutionaryChainId': PercChainConstants.evolutionaryChainId,
              'blockHeight': mockSeedLedger.blockHeight,
              'tipHash': PercChainTip.hash(mockSeedLedger),
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
          ..write(jsonEncode(mockSeedLedger.toJson()))
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

    expect(wallet.registrationAwaitingSeedAlignment, isFalse);
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(rendezvousRegisterCount, greaterThan(0));
  });
}