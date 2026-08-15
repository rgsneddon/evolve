import 'package:evolve/fcg/mishi/mishi_rpai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('learns permitted evolve-wallet and restore-privacy-vpn events; rejects others', () {
    final ned = RpaiLearner();
    expect(ned.learnedCount, 0);

    final wallet = ned.learn(const RpaiEvent(
      source: rpaiSourceEvolveWallet,
      kind: 'tab_click',
      payload: 'wallet',
    ));
    expect(wallet.accepted, isTrue);
    expect(wallet.eventId, isNotNull);

    final vpn = ned.learn(const RpaiEvent(
      source: rpaiSourceRestorePrivacyVpn,
      kind: 'connect',
      payload: 'residual-helsinki',
    ));
    expect(vpn.accepted, isTrue);

    final denied = ned.learn(const RpaiEvent(
      source: 'random-website',
      kind: 'scrape',
      payload: 'nope',
    ));
    expect(denied.accepted, isFalse);
    expect(denied.reason, 'source_not_permitted');

    expect(ned.learnedCount, 2);
    expect(ned.rejectedCount, 1);
    final stats = ned.stats();
    expect(stats.walletEvents, 1);
    expect(stats.vpnEvents, 1);
    expect(stats.learned, 2);
    expect(stats.rejected, 1);
    expect(stats.byKind['tab_click'], 1);
    expect(stats.byKind['connect'], 1);
    expect(stats.byKind.containsKey('scrape'), isFalse);
    expect(stats.sotaAccuracy, RpaiBenchmarkTargets.sotaAccuracy);
    expect(stats.capabilityMatrix.keys, isNotEmpty);
  });
}
