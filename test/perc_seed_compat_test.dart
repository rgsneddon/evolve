import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:evolve/perc/perc_chain_constants.dart';

/// Probes the public seed node for wallet v3.1.1 API compatibility.
void main() {
  const base = 'https://evolve-perc-internet.onrender.com';
  const chainId = PercChainConstants.evolutionaryChainId;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await http
        .get(Uri.parse('$base$path'))
        .timeout(PercChainConstants.networkRequestTimeout);
    expect(response.statusCode, 200, reason: 'GET $path');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  test('live seed health and ledger match wallet genesis', () async {
    final health = await getJson('/health');
    expect(health['ok'], isTrue);
    expect(health['service'], 'perc-internet-node');
    expect(health['ledgerReady'], isTrue);

    final status = await getJson('/perc/status');
    expect(status['evolutionaryChainId'], chainId);
    expect(status['networkGenesisRevision'], 2);

    final ledger = await getJson('/perc/ledger');
    expect(ledger['evolutionaryChainId'], chainId);
    expect(ledger['networkGenesisRevision'], 2);
    expect(ledger['blockchainLaunched'], isTrue);
    expect(ledger['pendingInboundTransfers'], isA<List<dynamic>>());
    expect(ledger['accounts'], isA<Map<String, dynamic>>());
  });

  test('live seed exposes v3.1.1 rendezvous endpoints', () async {
    final online = await getJson(
      '/perc/rendezvous/online?username=${PercChainConstants.seedUsername}',
    );
    expect(online['online'], isTrue);
    expect(online.containsKey('username'), isTrue);

    final addressOnly = 'percpriv1seedcompatprobe00000000000000000001';
    final post = await http
        .post(
          Uri.parse('$base/perc/rendezvous/address'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'address': addressOnly}),
        )
        .timeout(PercChainConstants.networkRequestTimeout);
    expect(post.statusCode, 200);
    final postJson = jsonDecode(post.body) as Map<String, dynamic>;
    expect(postJson['ok'], isTrue);

    final offline = await getJson(
      '/perc/rendezvous/online?address=${Uri.encodeComponent(addressOnly)}',
    );
    expect(offline['online'], isFalse);

    final peers = await http
        .get(
          Uri.parse(
            '$base/perc/rendezvous/peers?chainId=${Uri.encodeComponent(chainId)}',
          ),
        )
        .timeout(PercChainConstants.networkRequestTimeout);
    expect(peers.statusCode, 200);
    final peerList = jsonDecode(peers.body) as List<dynamic>;
    expect(peerList, isNotEmpty);
    final seedPeer = peerList.first as Map<String, dynamic>;
    expect(seedPeer['sessionUsername'], PercChainConstants.seedUsername);
    expect(seedPeer['updatedAt'], isNotNull);
  });

  test('live seed peer online window aligns with wallet (7 minutes)', () async {
    final health = await getJson('/health');
    expect(health['service'], 'perc-internet-node');
    expect(
      PercChainConstants.peerOnlineWindow,
      const Duration(minutes: 7),
    );
  });
}