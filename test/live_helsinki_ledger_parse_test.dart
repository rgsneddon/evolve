import 'dart:convert';

import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_network_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android-style client: Helsinki base + /perc paths import past height 0',
      () async {
    const base = 'https://135.181.152.10.sslip.io/perc';
    final client = PercNetworkClient();

    final status = await client.fetchStatus(base);
    expect(status, isNotNull, reason: 'seed /perc/status must succeed');
    expect(status!.blockHeight, greaterThan(0));
    // ignore: avoid_print
    print('status height=${status.blockHeight} tip=${status.tipHash}');

    final remote = await client.fetchLedger(base);
    expect(remote, isNotNull, reason: 'seed /perc/ledger must parse');
    expect(remote!.blockHeight, status.blockHeight);
    // ignore: avoid_print
    print(
      'ledger height=${remote.blockHeight} genesis=${remote.networkGenesisRevision}',
    );

    final local = PercLedger.empty()..networkGenesisRevision = 2;
    expect(local.blockHeight, 0);
    local.importPeerLedger(
      remote,
      expectedTipHash: PercChainTip.hash(remote),
    );
    expect(local.blockHeight, remote.blockHeight);
    expect(local.blockHeight, greaterThan(0));
    // ignore: avoid_print
    print('imported local height=${local.blockHeight}');

    final renderPeers = remote.networkNodes.values
        .where((n) => (n.endpoint ?? '').contains('onrender.com'))
        .length;
    // ignore: avoid_print
    print('render peer ads in public ledger: $renderPeers');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('single and double public status paths agree', () async {
    final single = await http
        .get(Uri.parse('https://135.181.152.10.sslip.io/perc/status'))
        .timeout(const Duration(seconds: 20));
    final doublePath = await http
        .get(Uri.parse('https://135.181.152.10.sslip.io/perc/perc/status'))
        .timeout(const Duration(seconds: 20));
    expect(single.statusCode, 200);
    expect(doublePath.statusCode, 200);
    final a = jsonDecode(single.body) as Map<String, dynamic>;
    final b = jsonDecode(doublePath.body) as Map<String, dynamic>;
    expect(a['blockHeight'], b['blockHeight']);
    expect(a['blockHeight'], greaterThan(0));
  });
}
