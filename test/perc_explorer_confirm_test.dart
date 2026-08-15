import 'package:evolve/fcg/mishi/mishi_rpai.dart';
import 'package:evolve/perc/services/perc_action_block.dart';
import 'package:evolve/perc/services/perc_explorer_confirm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirm of a real block returns confirmed', () {
    final chain = PercActionChain();
    final learner = RpaiLearner();
    learner.learn(const RpaiEvent(
      source: rpaiSourceEvolveWallet,
      kind: 'tab_click',
      payload: 'wallet',
    ));
    final explorer = PercExplorerConfirm(chain: chain, learner: learner);
    final block = chain.recordTabClick('security');
    final result = explorer.confirm(block.id);
    expect(result.status, 'confirmed');
    expect(result.block, isNotNull);
    expect(result.toJson()['confirmed'], isTrue);
  });

  test('unknown id returns not_found and empty id is rejected — never throws', () {
    final explorer = PercExplorerConfirm(chain: PercActionChain(), learner: RpaiLearner());
    final missing = explorer.confirm('no-such-block');
    expect(missing.status, 'not_found');
    expect(missing.block, isNull);
    expect(missing.toJson().containsKey('status'), isTrue);
    final rejected = explorer.confirm('');
    expect(rejected.status, 'rejected');
    expect(rejected.reason, 'missing_id');
  });

  test('diagrams produce non-empty series for blocks wards mint rpAI plus NED stats', () {
    final chain = PercActionChain();
    final learner = RpaiLearner();
    chain.recordTabClick('wallet');
    chain.recordKeystroke('x');
    learner.learn(const RpaiEvent(
      source: rpaiSourceEvolveWallet,
      kind: 'keystroke',
      payload: 'x',
    ));
    learner.learn(const RpaiEvent(
      source: rpaiSourceRestorePrivacyVpn,
      kind: 'connect',
      payload: 'helsinki',
    ));
    final explorer = PercExplorerConfirm(chain: chain, learner: learner);
    final diagrams = explorer.diagrams(epochId: 'epoch-2026-08-w1');
    expect(diagrams.hasGraphs, isTrue);
    expect(diagrams.blockSeries, isNotEmpty);
    expect(diagrams.wardSeries, isNotEmpty);
    expect(diagrams.mintSeries, isNotEmpty);
    expect(diagrams.rpaiSeries, isNotEmpty);
    expect(diagrams.ned.identity, 'NED');
    expect(diagrams.ned.learned, 2);
    expect(diagrams.ned.walletEvents, 1);
    expect(diagrams.ned.vpnEvents, 1);
    expect(diagrams.toJson()['ned']['identity'], 'NED');
  });
}
