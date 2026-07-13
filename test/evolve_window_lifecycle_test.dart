import 'dart:io';

import 'package:evolve/platform/evolve_window_lifecycle.dart';
import 'package:evolve_tunnel/evolve_tunnel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tunnel.dart';

void main() {
  test('onWindowClose awaits tunnel teardown before allowing exit', () async {
    var running = true;
    var installed = true;
    final backend = TrackingProcessBackend(
      runImpl: (exe, args) async {
        if (args.isNotEmpty && args.first == 'query') {
          if (!installed) {
            return ProcessResult(
              0,
              1060,
              '',
              'FAILED 1060: The specified service does not exist',
            );
          }
          if (running) {
            return ProcessResult(0, 0, 'STATE              : 4  RUNNING', '');
          }
          return ProcessResult(0, 0, 'STATE              : 1  STOPPED', '');
        }
        if (args.isNotEmpty && args.first == 'stop') {
          running = false;
          return ProcessResult(0, 0, 'STOP', '');
        }
        if (args.isNotEmpty && args.first == 'delete') {
          installed = false;
          running = false;
          return ProcessResult(0, 0, 'deleted', '');
        }
        if (args.contains('/uninstalltunnelservice')) {
          installed = false;
          running = false;
          return ProcessResult(0, 0, 'ok', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );
    final wg = WireGuardController(
      node: VpnNodeConfig.vultrNode,
      processBackend: backend,
      fileExists: (_) => true,
      runner: backend.run,
    );
    final tunnel = EvolveTunnelController(
      wireGuard: wg,
      processBackend: backend,
      statusClient: FakeNodeStatusClient(),
    );
    tunnel.userInitiatedSession = true;
    tunnel.state = VpnConnectState.connected;

    final lifecycle = EvolveWindowLifecycle(tunnel);
    final allowClose = await lifecycle.onWindowClose();

    expect(allowClose, isTrue);
    expect(tunnel.state, VpnConnectState.disconnected);
    expect(tunnel.disconnectCallCount, greaterThan(0));
    expect(installed, isFalse);
    expect(running, isFalse);
  });
}