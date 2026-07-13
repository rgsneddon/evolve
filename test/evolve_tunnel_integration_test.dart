import 'package:evolve_tunnel/evolve_tunnel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evolve_app consumer loads tunnel package with disconnected default', () {
    final ctl = EvolveTunnelController();
    expect(ctl.state, VpnConnectState.disconnected);
    expect(ctl.userInitiatedSession, isFalse);
    expect(ctl.canConnect, isFalse);
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
}