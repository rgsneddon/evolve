import 'dart:io';

import 'package:evolve_tunnel/evolve_tunnel.dart';

class FakeNodeStatusClient extends NodeStatusClient {
  FakeNodeStatusClient() : super(node: VpnNodeConfig.vultrNode);

  @override
  Future<NodeStatusSnapshot?> fetchStatus() async {
    return const NodeStatusSnapshot(
      lastLogPurgeIso: '2026-07-10T12:46:25+00:00',
      purgeIntervalHours: 4,
      regionLabel: 'New Jersey, USA',
      regionDetail: 'Piscataway, New Jersey, United States (Vultr)',
      endpoint: '104.156.224.47:51820',
    );
  }
}

EvolveTunnelController createMockTunnelController() {
  final backend = TrackingProcessBackend(
    runImpl: (_, __) async => ProcessResult(0, 0, '', ''),
  );
  final wg = WireGuardController(
    node: VpnNodeConfig.vultrNode,
    processBackend: backend,
    fileExists: (_) => true,
    runner: backend.run,
  );
  return EvolveTunnelController(
    wireGuard: wg,
    processBackend: backend,
    statusClient: FakeNodeStatusClient(),
  );
}