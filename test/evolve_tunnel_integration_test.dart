import 'dart:io';

import 'package:evolve_tunnel/evolve_tunnel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tunnel.dart';

void main() {
  test('evolve_app consumer loads tunnel package with disconnected default', () {
    final ctl = createMockTunnelController();
    expect(ctl.state, VpnConnectState.disconnected);
    expect(ctl.userInitiatedSession, isFalse);
    expect(ctl.canConnect, isFalse);
  });

  test('wallet gate: connect rejected when hasAppAccess is false', () async {
    final ctl = createMockTunnelController();
    ctl.walletAccessGranted = false;
    ctl.appInForeground = true;

    await ctl.connectTunnel();

    expect(ctl.state, VpnConnectState.error);
    expect(ctl.userInitiatedSession, isFalse);
    expect(ctl.connectCallCount, 1);
  });

  test('foreground gate: connect rejected when app is backgrounded', () async {
    final ctl = createMockTunnelController();
    ctl.walletAccessGranted = true;
    ctl.appInForeground = false;

    await ctl.connectTunnel();

    expect(ctl.state, VpnConnectState.error);
    expect(ctl.userInitiatedSession, isFalse);
  });

  test('no auto-connect: pollLogStatus never spawns tunnel without user action',
      () async {
    var connectOps = 0;
    final backend = TrackingProcessBackend(
      runImpl: (exe, args) async {
        if (args.isNotEmpty && args.first == 'start') connectOps++;
        if (args.contains('/installtunnelservice')) connectOps++;
        return ProcessResult(0, 0, '', '');
      },
    );
    final wg = WireGuardController(
      node: VpnNodeConfig.vultrNode,
      processBackend: backend,
      fileExists: (_) => true,
      runner: backend.run,
    );
    final ctl = EvolveTunnelController(
      wireGuard: wg,
      processBackend: backend,
      statusClient: FakeNodeStatusClient(),
    );
    ctl.walletAccessGranted = true;
    ctl.appInForeground = true;

    await ctl.pollLogStatus();

    expect(ctl.state, VpnConnectState.disconnected);
    expect(ctl.userInitiatedSession, isFalse);
    expect(connectOps, 0);
  });

  test('teardown on app close disconnects and clears tracked VPN child PIDs',
      () async {
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
    backend.trackedChildPids.add(4242);
    final wg = WireGuardController(
      node: VpnNodeConfig.vultrNode,
      processBackend: backend,
      fileExists: (_) => true,
      runner: backend.run,
    );
    final ctl = EvolveTunnelController(
      wireGuard: wg,
      processBackend: backend,
      statusClient: FakeNodeStatusClient(),
    );
    ctl.userInitiatedSession = true;
    ctl.state = VpnConnectState.connected;

    await ctl.teardownOnAppClose();

    expect(ctl.state, VpnConnectState.disconnected);
    expect(ctl.userInitiatedSession, isFalse);
    expect(ctl.trackedVpnChildPidCount, 0);
    expect(ctl.disconnectCallCount, greaterThan(0));
    expect(installed, isFalse);
    expect(running, isFalse);
  });

  test('disconnectTunnel removes running tunnel service', () async {
    var running = true;
    var installed = true;
    final tmp = Directory.systemTemp.createTempSync('evolve_int_disc_');
    final confPath = '${tmp.path}${Platform.pathSeparator}demo1.conf';
    File(confPath).writeAsStringSync('[Interface]\nAddress = 10.66.66.2/32\n');
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
      configPath: confPath,
      processBackend: backend,
      fileExists: (p) => File(p).existsSync(),
      runner: backend.run,
      configResolver: TunnelConfigResolver(
        node: VpnNodeConfig.vultrNode,
        explicitPath: confPath,
      ),
    );
    final ctl = EvolveTunnelController(
      wireGuard: wg,
      processBackend: backend,
      statusClient: FakeNodeStatusClient(),
    );
    ctl.userInitiatedSession = true;
    ctl.state = VpnConnectState.connected;

    await ctl.disconnectTunnel();

    expect(ctl.state, VpnConnectState.disconnected);
    expect(installed, isFalse);
    expect(running, isFalse);
    tmp.deleteSync(recursive: true);
  });

  test('log deletion presenter renders 4-hour policy from status JSON', () {
    const presenter = LogDeletionPresenter();
    final out = presenter.renderFromStatusJson({
      'purge_interval_hours': 4,
      'last_log_purge': '2026-07-10T12:46:25+00:00',
    });
    expect(out, contains('every 4 hours'));
    expect(out, contains('2026-07-10T12:46:25+00:00'));
  });

  test('WireGuardController resolves bundled install-dir wireguard.exe first',
      () {
    final install = Directory.systemTemp.createTempSync('evolve_int_wg_');
    final vpnDir = Directory('${install.path}${Platform.pathSeparator}vpn');
    vpnDir.createSync();
    final bundled = File('${vpnDir.path}${Platform.pathSeparator}wireguard.exe');
    bundled.writeAsStringSync('stub');

    final wg = WireGuardController(
      node: VpnNodeConfig.vultrNode,
      installDir: install.path,
      fileExists: (p) => File(p).existsSync(),
    );

    expect(wg.resolvedWireGuardExe, bundled.path);
    install.deleteSync(recursive: true);
  });

  test('stopStatusPolling leaves client usable after tab leave and return',
      () async {
    final ctl = createMockTunnelController();
    ctl.startStatusPolling();
    ctl.stopStatusPolling();

    await ctl.pollLogStatus();

    expect(ctl.logDeletionOutput, contains('every 4 hours'));
  });
}