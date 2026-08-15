@Tags(['serial'])
library perc_dead_9477_sync_and_loading_test;

import 'dart:convert';

import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_client.dart';
import 'package:evolve/perc/services/perc_network_config.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:evolve/perc/services/perc_network_rendezvous.dart';
import 'package:evolve/perc/services/perc_public_endpoint.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _dead9477 = 'http://217.142.21.226:9477';
const _rendezvousBase = 'https://rendezvous.test/perc';

PercLedger _tallRendezvousLedger({int extraBlocks = 8}) {
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
        timestamp: DateTime.utc(2026, 8, 15, 12, i),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'rendezvous tip $i',
      ),
    );
  }
  return seed;
}

class _ScriptedPercHttp extends http.BaseClient {
  _ScriptedPercHttp(this.ledger);

  final PercLedger ledger;
  final probed = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    probed.add('${request.method} $url');
    if (url.contains('217.142.21.226')) {
      throw StateError('dead :9477 must not be probed: $url');
    }

    final path = request.url.path;
    Object payload = {'ok': true};
    if (path.endsWith('/perc/status') || path.endsWith('/status')) {
      payload = {
        'evolutionaryChainId': PercChainConstants.evolutionaryChainId,
        'blockHeight': ledger.blockHeight,
        'tipHash': PercChainTip.hash(ledger),
        'revision': 1,
        'networkGenesisRevision': 2,
        'sessionUsername': PercChainConstants.seedUsername,
        'endpoint': _rendezvousBase,
      };
    } else if (path.endsWith('/perc/ledger') || path.endsWith('/ledger')) {
      if (request.method == 'GET' &&
          request.url.queryParameters.isNotEmpty) {
        payload = {'ledger': ledger.toJson()};
      } else if (request.method == 'GET') {
        payload = ledger.toJson();
      }
    } else if (path.contains('/rendezvous/peers')) {
      payload = [
        {
          'evolutionaryChainId': PercChainConstants.evolutionaryChainId,
          'blockHeight': 1,
          'tipHash': 'dead-9477-tip',
          'revision': 1,
          'networkGenesisRevision': 2,
          'sessionUsername': 'nat_phone',
          'endpoint': _dead9477,
        },
      ];
    }

    final body = utf8.encode(jsonEncode(payload));
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([body]),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  late PercLedger rendezvousLedger;
  late _ScriptedPercHttp scripted;

  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkConfig.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = true;
    rendezvousLedger = _tallRendezvousLedger();
    scripted = _ScriptedPercHttp(rendezvousLedger);
    PercNetworkConfig.setCachedForTest(
      const PercNetworkConfig(
        rendezvousUrl: _rendezvousBase,
        seedUsername: PercChainConstants.seedUsername,
        networkGenesisRevision: 2,
        publicEndpointOverride: '',
        publicIpLookupUrls: [],
      ),
    );
  });

  tearDown(() async {
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercNetworkConfig.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('evolve-apple adopts rendezvous tip and ignores dead public-ip:9477',
      () async {
    final tip = PercChainTip.height(rendezvousLedger);
    expect(
      PercPublicEndpoint.preferredChainFetchEndpoint(
        rendezvousUrl: _rendezvousBase,
        advertised: const [_dead9477],
      ),
      _rendezvousBase,
    );

    PercNetworkCoordinator.disableLiveNodesForTests = false;
    PercNetworkCoordinator.instance.useHttpStackForTest(
      client: PercNetworkClient(client: scripted),
      rendezvous: PercNetworkRendezvous(client: scripted),
    );

    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);
    final hub = PercLedgerHub.instance;
    hub.ledger.ensureTreasuryAccount();
    hub.ledger.setupTreasuryPassword('password12345');
    hub.ledger.networkGenesisRevision = 2;
    hub.ledger.updatePeerFromStatus(
      const PercNetworkStatus(
        evolutionaryChainId: PercChainConstants.evolutionaryChainId,
        blockHeight: 1,
        tipHash: 'dead-9477-tip',
        revision: 1,
        networkGenesisRevision: 2,
        sessionUsername: 'nat_phone',
        endpoint: _dead9477,
      ),
      online: true,
    );

    await hub.network.forceSyncWalletToSeed();
    expect(PercChainTip.height(hub.ledger), tip);
    expect(
      scripted.probed.any((u) => u.contains('217.142.21.226')),
      isFalse,
    );
  });

  test('evolve-apple post-register connect completes fast with dead :9477',
      () async {
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercNetworkCoordinator.instance.useHttpStackForTest(
      client: PercNetworkClient(client: scripted),
      rendezvous: PercNetworkRendezvous(client: scripted),
    );

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('fastuser', 'password12345');
    final sw = Stopwatch()..start();
    await wallet.completeRegistrationSeedSetup(enableSeed: false);
    sw.stop();
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(sw.elapsed, lessThan(PercChainConstants.networkRequestTimeout));
  });
}
