import 'dart:convert';
import 'dart:io';

import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:http/http.dart' as http;

/// Mirrors PercNetworkClient path join used on Android Evolve.
Uri resolve(String endpoint, String path) {
  final base =
      endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;
  return Uri.parse('$base$path');
}

Future<void> main() async {
  const base = 'https://135.181.152.10.sslip.io/perc';
  final statusUri = resolve(base, '/perc/status');
  final ledgerUri = resolve(base, '/perc/ledger');
  stdout.writeln('statusUri=$statusUri');
  stdout.writeln('ledgerUri=$ledgerUri');

  final statusRes =
      await http.get(statusUri).timeout(const Duration(seconds: 30));
  stdout.writeln('status HTTP ${statusRes.statusCode}');
  if (statusRes.statusCode != 200) {
    stderr.writeln(statusRes.body);
    exit(2);
  }
  final status = jsonDecode(statusRes.body) as Map<String, dynamic>;
  final height = status['blockHeight'] as int? ?? 0;
  stdout.writeln('status height=$height tip=${status['tipHash']}');

  final ledgerRes =
      await http.get(ledgerUri).timeout(const Duration(seconds: 60));
  stdout.writeln('ledger HTTP ${ledgerRes.statusCode} bytes=${ledgerRes.body.length}');
  if (ledgerRes.statusCode != 200) {
    stderr.writeln(ledgerRes.body);
    exit(3);
  }
  final map = jsonDecode(ledgerRes.body) as Map<String, dynamic>;
  final remote = PercLedger.fromJson(map);
  stdout.writeln(
    'parsed height=${remote.blockHeight} genesis=${remote.networkGenesisRevision} accounts=${remote.accounts.length}',
  );

  final local = PercLedger.empty()..networkGenesisRevision = 2;
  stdout.writeln('local before=${local.blockHeight}');
  local.importPeerLedger(
    remote,
    expectedTipHash: PercChainTip.hash(remote),
  );
  stdout.writeln('local after=${local.blockHeight}');

  // Client tip vs server tip
  final clientTip = PercChainTip.hash(remote);
  final serverTip = status['tipHash'] as String? ?? '';
  stdout.writeln('clientTip=$clientTip');
  stdout.writeln('serverTip=$serverTip');
  stdout.writeln('tipMatch=${clientTip == serverTip}');

  final render = remote.networkNodes.values
      .where((n) => (n.endpoint ?? '').contains('onrender.com'))
      .length;
  stdout.writeln('renderPeerAds=$render');

  if (local.blockHeight <= 0) {
    stderr.writeln('FAIL still height 0');
    exit(4);
  }
  if (local.blockHeight != height) {
    stderr.writeln('FAIL height mismatch local=${local.blockHeight} status=$height');
    exit(5);
  }
  stdout.writeln('OK cold import past 0');
}
