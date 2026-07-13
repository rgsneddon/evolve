import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_block_display_label.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_config.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:evolve/perc/services/perc_transfer_relay_ack.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.networkGenesisRevision = 2;
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

PercLedger _tallSeedLedger() {
  final seed = PercLedger.empty();
  _seed(seed);
  for (var i = 0; i < 3; i++) {
    seed.blocks.add(
      PercBlock(
        index: seed.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'Seed ahead $i',
      ),
    );
  }
  return seed;
}

void main() {
  HttpServer? server;
  late PercLedger mockSeedLedger;
  final relaySlots = <String, Map<String, dynamic>>{};
  String? relayedTransferTxId;
  int? relayedCanonicalIndex;

  setUp(() async {
    PercLedgerHub.resetForTest();
    PercNetworkConfig.resetForTest();
    mockSeedLedger = _tallSeedLedger();
    relaySlots.clear();
    relayedTransferTxId = null;
    relayedCanonicalIndex = null;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${server!.port}';

    PercNetworkConfig.setCachedForTest(
      PercNetworkConfig(
        rendezvousUrl: base,
        seedUsername: PercChainConstants.seedUsername,
        networkGenesisRevision: 2,
        publicEndpointOverride: base,
        publicIpLookupUrls: const [],
      ),
    );

    server!.listen((request) async {
      final path = request.uri.path;

      if (request.method == 'PUT' && path == '/perc/rendezvous/ledger') {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final username = (json['username'] as String? ?? '').trim();
        if (username.isNotEmpty) {
          relaySlots[username] = json;
        }
        final relay = PercLedger.fromJson(json['ledger'] as Map<String, dynamic>);
        final ack = PercTransferRelayAck.acknowledgeRelayTransfers(
          mockSeedLedger,
          relay,
        );
        if (ack.transferIds.isNotEmpty) {
          relayedTransferTxId = ack.transferIds.first;
          relayedCanonicalIndex = ack.canonicalIndices.first;
        }
        request.response
          ..statusCode = 200
          ..write(jsonEncode({'ok': true, 'imported': ack.ok}))
          ..close();
        return;
      }

      if (request.method == 'GET' && path == '/perc/rendezvous/ledger') {
        final username = request.uri.queryParameters['username']?.trim();
        final slot = username != null ? relaySlots[username] : null;
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(
              slot ?? {'ledger': mockSeedLedger.toJson()},
            ),
          )
          ..close();
        return;
      }

      if (request.method == 'POST' &&
          (path == '/perc/rendezvous/register' ||
              path == '/perc/rendezvous/address' ||
              path == '/perc/ledger')) {
        request.response
          ..statusCode = 200
          ..write('{"ok":true}')
          ..close();
        return;
      }

      if (request.method == 'GET' && path == '/perc/rendezvous/online') {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"online":false}')
          ..close();
        return;
      }

      if (request.method == 'GET' && path == '/perc/rendezvous/address') {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'address': request.uri.queryParameters['address'] ?? '',
            }),
          )
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

      request.response
        ..statusCode = 404
        ..close();
    });

    PercNetworkCoordinator.disableLiveNodesForTests = true;
  });

  tearDown(() async {
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    await server?.close(force: true);
    server = null;
    PercNetworkConfig.resetForTest();
    PercLedgerHub.resetForTest();
  });

  test(
    'PercWalletProvider.send HTTP relay acks transfer on mock seed ledger',
    () async {
      final store = PercWalletStoreMemory();
      final wallet = PercWalletProvider(store: store);
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');

      final ledger = PercLedgerHub.instance.ledger;
      ledger.networkGenesisRevision = 2;
      ledger.register('alice', 'password12345');
      ledger.register('bob', 'password12345');
      ledger.launchBlockchain();
      ledger.consumeBlockchainLaunchEvent();
      ledger.creditScenario(username: 'alice', percentChance: 80);
      await wallet.login('alice', 'password12345');

      final bobAddr = wallet.addressForUsername('bob');
      final balanceBefore = wallet.balance;

      PercNetworkCoordinator.disableLiveNodesForTests = false;
      PercNetworkCoordinator.instance.setSyncStateForTest(
        PercNetworkSyncState.synced,
      );
      PercNetworkCoordinator.instance.setNetworkBlockHeightForTest(
        mockSeedLedger.blockHeight,
      );
      PercNetworkCoordinator.instance.setSeedConnectedForTest(true);

      await wallet.send(
        toAddress: bobAddr,
        amountText: '0.00000005',
        sendAuthPassword: 'password12345',
      );

      expect(wallet.errorMessage, isNull);

      final senderLedger = PercLedgerHub.instance.ledger;
      final senderTransfer = senderLedger.blocks
          .expand((b) => b.transactions)
          .firstWhere((t) => t.kind == PercTxKind.transfer);

      expect(relayedTransferTxId, senderTransfer.id);
      final senderBlockIndex = senderLedger.blocks
          .firstWhere(
            (b) => b.transactions.any((t) => t.id == senderTransfer.id),
          )
          .index;
      expect(relayedCanonicalIndex, senderBlockIndex);

      final seedBlock = mockSeedLedger.blocks.firstWhere(
        PercBlockDisplayLabel.hasTransfer,
      );
      expect(
        PercBlockDisplayLabel.transferTransactions(seedBlock).first.id,
        senderTransfer.id,
      );
      expect(seedBlock.index, relayedCanonicalIndex);
      expect(
        balanceBefore.microUnits,
        greaterThan(wallet.balance.microUnits),
      );

      print(
        'HTTP_RELAY: tx.id=$relayedTransferTxId canonicalIndex=$relayedCanonicalIndex '
        'seedHeight=${mockSeedLedger.blockHeight} kind=transfer',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}