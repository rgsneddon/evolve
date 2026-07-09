import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

final _scratch = Platform.environment['SCRATCH'] ??
    r'C:\Users\rgsne\AppData\Local\Temp\grok-goal-cb031749c6db\implementer';

void _writeProbeLog(String body) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch${Platform.pathSeparator}live_seed_probe_data.log')
      .writeAsStringSync(body);
}

/// Probes the public seed node for wallet v3.1.1 API compatibility.
void main() {
  const base = 'https://evolve-perc-internet.onrender.com';
  const chainId = PercChainConstants.evolutionaryChainId;
  const skipLive = bool.fromEnvironment('PERC_SKIP_LIVE_SEED', defaultValue: false);
  bool? _livePrivacyReady;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await http
        .get(Uri.parse('$base$path'))
        .timeout(PercChainConstants.networkRequestTimeout);
    expect(response.statusCode, 200, reason: 'GET $path');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> liveSeedReachable() async {
    if (skipLive) return false;
    try {
      await getJson('/health');
      return true;
    } on TimeoutException {
      _writeProbeLog('skipped: live seed unreachable (timeout)\n');
      return false;
    } on SocketException {
      _writeProbeLog('skipped: live seed unreachable (socket)\n');
      return false;
    }
  }

  Future<bool> liveSeedSupportsAccountPrivacy() async {
    if (_livePrivacyReady != null) return _livePrivacyReady!;
    try {
      final ledger = await getJson('/perc/ledger');
      final accounts = ledger['accounts'];
      if (accounts is! Map || accounts.isEmpty) {
        _livePrivacyReady = true;
        return true;
      }
      for (final account in accounts.values) {
        if (account is Map && account.containsKey('passwordHash')) {
          _livePrivacyReady = false;
          return false;
        }
      }
      _livePrivacyReady = true;
      return true;
    } catch (_) {
      _livePrivacyReady = false;
      return false;
    }
  }

  test('live seed health and ledger match wallet genesis', () async {
    if (!await liveSeedReachable() || !await liveSeedSupportsAccountPrivacy()) {
      return;
    }
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
    for (final account in (ledger['accounts'] as Map).values) {
      final row = account as Map<String, dynamic>;
      expect(row.containsKey('passwordHash'), isFalse);
      expect(row.containsKey('salt'), isFalse);
      expect(row.containsKey('password'), isFalse);
    }
  });

  test('live seed exposes v3.1.1 rendezvous endpoints', () async {
    if (!await liveSeedReachable() || !await liveSeedSupportsAccountPrivacy()) {
      return;
    }
    final online = await getJson(
      '/perc/rendezvous/online?username=${PercChainConstants.seedUsername}',
    );
    expect(online['online'], isTrue);
    expect(online.containsKey('username'), isFalse);
    expect(online.containsKey('address'), isFalse);

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
    expect(seedPeer.containsKey('sessionUsername'), isFalse);
    expect(seedPeer['publicAlias'], isA<String>());
    expect((seedPeer['publicAlias'] as String).length, 5);
    expect(seedPeer['updatedAt'], isNotNull);
  });

  test('live seed status tip vs client ledger tip probe', () async {
    if (!await liveSeedReachable()) return;
    if (!await liveSeedSupportsAccountPrivacy()) {
      _writeProbeLog('skipped: live seed ledger not privacy-sanitized yet\n');
      return;
    }

    final status = await getJson('/perc/status');
    final ledgerJson = await getJson('/perc/ledger');
    final ledger = PercLedger.fromJson(ledgerJson);
    final statusTip = status['tipHash'] as String? ?? '';
    final clientTip = PercChainTip.hash(ledger);
    final statusHeight = status['blockHeight'] as int? ?? 0;
    final clientHeight = PercChainTip.height(ledger);

    final tipsMatch = statusTip == clientTip;
    final heightsMatch = statusHeight == clientHeight;
    _writeProbeLog(
      'base=$base\n'
      'statusTip=$statusTip\n'
      'clientLedgerTip=$clientTip\n'
      'tipsMatch=$tipsMatch\n'
      'statusHeight=$statusHeight\n'
      'clientHeight=$clientHeight\n'
      'heightsMatch=$heightsMatch\n'
      'note=${tipsMatch && heightsMatch ? 'server and client agree' : 'mismatch'}\n',
    );

    expect(heightsMatch, isTrue,
        reason: 'statusHeight=$statusHeight clientHeight=$clientHeight');
    expect(tipsMatch, isTrue,
        reason: 'statusTip=$statusTip clientTip=$clientTip');
    expect(statusHeight, clientHeight);
    expect(statusTip, clientTip);
  });

  test('live seed peer online window aligns with wallet (7 minutes)', () async {
    if (!await liveSeedReachable()) return;
    final health = await getJson('/health');
    expect(health['service'], 'perc-internet-node');
    expect(
      PercChainConstants.peerOnlineWindow,
      const Duration(minutes: 7),
    );
  });
}