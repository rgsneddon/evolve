@Tags(['serial'])
library perc_dead_9477_sync_and_loading_test;

import 'dart:convert';
import 'dart:io';

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
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/screens/evolve_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'test_locale_provider.dart';

const _dead9477 = 'http://217.142.21.226:9477';
const _rendezvousBase = 'https://rendezvous.test/perc';

final _scratch = Platform.environment['SCRATCH'] ??
    '/var/folders/qb/tz4y4zts04z4846pbq95l6kw0000gp/T/grok-goal-5fa0907a8752/implementer';

void _writeLog(String filename, String body) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch${Platform.pathSeparator}$filename').writeAsStringSync(body);
}

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
    EvolveLoadingScreen.introDurationOverride = Duration.zero;
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
    EvolveLoadingScreen.introDurationOverride = null;
  });

  test(
    'shipped sync adopts rendezvous tip and ignores dead public-ip:9477',
    () async {
      final tip = PercChainTip.height(rendezvousLedger);
      expect(tip, greaterThan(1));

      expect(PercPublicEndpoint.isChainFetchEndpoint(_dead9477), isFalse);
      expect(
        PercPublicEndpoint.preferredChainFetchEndpoint(
          rendezvousUrl: _rendezvousBase,
          advertised: const [_dead9477],
        ),
        _rendezvousBase,
      );

      final hop = PercPublicEndpoint.preferredChainFetchEndpoint(
        rendezvousUrl: _rendezvousBase,
        advertised: const [_dead9477],
      )!;
      final shipped = PercNetworkClient(client: scripted);
      final deadSw = Stopwatch()..start();
      final deadStatus = await shipped.fetchStatus(_dead9477);
      final deadLedger = await shipped.fetchLedger(_dead9477);
      deadSw.stop();
      expect(deadStatus, isNull);
      expect(deadLedger, isNull);
      expect(deadSw.elapsedMilliseconds, lessThan(200));
      expect(
        scripted.probed.any((u) => u.contains('217.142.21.226')),
        isFalse,
      );

      final remote = await shipped.fetchLedger(hop);
      expect(remote, isNotNull);
      expect(PercChainTip.height(remote!), tip);

      final local = PercLedger.empty()..networkGenesisRevision = 2;
      expect(PercChainTip.height(local), lessThan(tip));
      PercChainTip.adoptTallerTip(
        local,
        remote,
        expectedTipHash: PercChainTip.hash(remote),
      );
      expect(PercChainTip.height(local), tip);

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

      final localBefore = PercChainTip.height(hub.ledger);
      expect(localBefore, lessThan(tip));

      final sw = Stopwatch()..start();
      await hub.network.forceSyncWalletToSeed();
      sw.stop();

      final after = PercChainTip.height(hub.ledger);
      final probedDead =
          scripted.probed.any((u) => u.contains('217.142.21.226'));
      _writeLog(
        'perc-sync-tip.log',
        'deadPeer=$_dead9477\n'
        'rendezvous=$_rendezvousBase\n'
        'localBefore=$localBefore\n'
        'rendezvousTip=$tip\n'
        'localAfter=$after\n'
        'elapsedMs=${sw.elapsedMilliseconds}\n'
        'probedDead9477=$probedDead\n'
        'preferred=$hop\n'
        'probes=${scripted.probed.join(' | ')}\n',
      );

      expect(after, tip);
      expect(hub.network.networkBlockHeight, tip);
      expect(probedDead, isFalse);
      expect(
        sw.elapsed,
        lessThan(PercChainConstants.networkRequestTimeout),
      );
    },
  );

  test(
    'post-register splash connect completes fast with dead :9477',
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
      PercLedgerHub.instance.ledger.networkGenesisRevision = 2;

      await wallet.register('fastuser', 'password12345');
      expect(wallet.pendingSeedSetup, isTrue);
      expect(wallet.isWalletConnectComplete, isFalse);

      final sw = Stopwatch()..start();
      await wallet.completeRegistrationSeedSetup(enableSeed: false);
      sw.stop();

      _writeLog(
        'wallet-loading.log',
        'deadPeer=$_dead9477\n'
        'rendezvous=$_rendezvousBase\n'
        'elapsedMs=${sw.elapsedMilliseconds}\n'
        'walletConnectComplete=${wallet.isWalletConnectComplete}\n'
        'hasAppAccess=${wallet.hasAppAccess}\n'
        'pendingSeed=${wallet.pendingSeedSetup}\n'
        'postLoginSyncing=${wallet.isPostLoginSyncing}\n'
        'sessionTimeoutEnabled=${PercWalletProvider.sessionTimeoutEnabled}\n'
        'probedDead9477=${scripted.probed.any((u) => u.contains('217.142.21.226'))}\n',
      );

      expect(wallet.hasAppAccess, isTrue);
      expect(wallet.isWalletConnectComplete, isTrue);
      expect(
        sw.elapsed,
        lessThan(PercChainConstants.networkRequestTimeout),
      );
    },
  );

  testWidgets(
    'Wallet loading… does not remain after registration finishes',
    (tester) async {
      PercNetworkCoordinator.disableLiveNodesForTests = true;
      PercWalletProvider.sessionTimeoutEnabled = true;

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.register('splashuser', 'password12345');
      await wallet.completeRegistrationSeedSetup(enableSeed: false);
      expect(wallet.isWalletConnectComplete, isTrue);

      PercWalletProvider.sessionTimeoutEnabled = false;
      wallet.noteUserActivity();

      final locale = await createTestLocaleProvider();
      final evolve = EvolveProvider();
      var entered = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wallet),
            ChangeNotifierProvider.value(value: locale),
            ChangeNotifierProvider.value(value: evolve),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                if (entered) {
                  return const Scaffold(body: Text('IN_APP'));
                }
                return EvolveLoadingScreen(
                  walletReady: true,
                  onAuthenticated: () => setState(() => entered = true),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Wallet loading…'), findsNothing);
      expect(find.text('IN_APP'), findsOneWidget);
    },
  );
}
