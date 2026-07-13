import 'dart:async';
import 'dart:io';

import 'package:evolve/platform/evolve_window_lifecycle.dart';
import 'package:evolve_tunnel/evolve_tunnel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

import 'mock_tunnel.dart';

class _RecordingWindowOps implements EvolveWindowOps {
  bool preventCloseEnabled = false;
  WindowListener? registeredListener;
  final Completer<void> destroyCompleter = Completer<void>();
  int destroyCallCount = 0;

  @override
  Future<void> setPreventClose(bool value) async {
    preventCloseEnabled = value;
  }

  @override
  Future<void> destroy() async {
    destroyCallCount++;
    if (!destroyCompleter.isCompleted) {
      destroyCompleter.complete();
    }
  }

  @override
  void addListener(WindowListener listener) {
    registeredListener = listener;
  }
}

TrackingProcessBackend _runningTunnelBackend() {
  var running = true;
  var installed = true;
  return TrackingProcessBackend(
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
}

void main() {
  test('register enables prevent-close interception on the desktop path',
      () async {
    final backend = _runningTunnelBackend();
    final tunnel = EvolveTunnelController(
      wireGuard: WireGuardController(
        node: VpnNodeConfig.vultrNode,
        processBackend: backend,
        fileExists: (_) => true,
        runner: backend.run,
      ),
      processBackend: backend,
      statusClient: FakeNodeStatusClient(),
    );
    final ops = _RecordingWindowOps();

    await registerEvolveWindowLifecycle(
      tunnel,
      windowOps: ops,
      enabled: true,
    );

    expect(ops.preventCloseEnabled, isTrue);
    expect(ops.registeredListener, isA<EvolveWindowLifecycle>());
    expect(EvolveWindowLifecycle.instance, isNotNull);
  });

  test('onWindowClose tears down VPN then destroys window (real WM_CLOSE path)',
      () async {
    final backend = _runningTunnelBackend();
    final tunnel = EvolveTunnelController(
      wireGuard: WireGuardController(
        node: VpnNodeConfig.vultrNode,
        processBackend: backend,
        fileExists: (_) => true,
        runner: backend.run,
      ),
      processBackend: backend,
      statusClient: FakeNodeStatusClient(),
    );
    tunnel.userInitiatedSession = true;
    tunnel.state = VpnConnectState.connected;

    final ops = _RecordingWindowOps();
    await registerEvolveWindowLifecycle(
      tunnel,
      windowOps: ops,
      enabled: true,
    );

    // window_manager calls onWindowClose synchronously without awaiting.
    ops.registeredListener!.onWindowClose();
    await ops.destroyCompleter.future.timeout(const Duration(seconds: 5));

    expect(tunnel.state, VpnConnectState.disconnected);
    expect(tunnel.disconnectCallCount, greaterThan(0));
    expect(ops.destroyCallCount, 1);
  });
}