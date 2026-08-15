import 'perc_action_block.dart';
import 'perc_voting_epoch_wards.dart';
import '../../fcg/mishi/mishi_rpai.dart';

/// Explorer confirm + diagram builders. Always returns confirm | not_found | rejected.
class PercExplorerDiagrams {
  const PercExplorerDiagrams({
    required this.blockSeries,
    required this.wardSeries,
    required this.mintSeries,
    required this.rpaiSeries,
    required this.ned,
  });

  final List<int> blockSeries;
  final List<int> wardSeries;
  final List<int> mintSeries;
  final List<int> rpaiSeries;
  final RpaiNedStats ned;

  bool get hasGraphs =>
      blockSeries.isNotEmpty &&
      wardSeries.isNotEmpty &&
      mintSeries.isNotEmpty &&
      rpaiSeries.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'graphs': {
          'blocks': blockSeries,
          'wards': wardSeries,
          'mint': mintSeries,
          'rpai': rpaiSeries,
        },
        'ned': ned.toJson(),
      };
}

class PercExplorerConfirm {
  PercExplorerConfirm({
    PercActionChain? chain,
    RpaiLearner? learner,
  })  : chain = chain ?? percActionChain,
        learner = learner ?? rpaiNed;

  final PercActionChain chain;
  final RpaiLearner learner;

  PercBlockConfirmResult confirm(String? id) => chain.confirm(id);

  PercExplorerDiagrams diagrams({String epochId = 'current'}) {
    final blocks = chain.blocks;
    final blockSeries = blocks.isEmpty
        ? <int>[0]
        : blocks.map((b) => b.index).toList();
    final wards = PercVotingEpochWards.wardsForEpoch(epochId);
    final wardSeries = wards.map((w) => w.wardIndex).toList();
    final mintSeries = List<int>.generate(
      blockSeries.length.clamp(1, 32),
      (i) => (i + 1) * 1, // relative mint ticks after the 2/3 cut
    );
    final stats = learner.stats();
    final rpaiSeries = stats.byKind.isEmpty
        ? <int>[stats.learned]
        : stats.byKind.values.toList();
    return PercExplorerDiagrams(
      blockSeries: blockSeries,
      wardSeries: wardSeries,
      mintSeries: mintSeries,
      rpaiSeries: rpaiSeries,
      ned: stats,
    );
  }
}

final PercExplorerConfirm percExplorerConfirm = PercExplorerConfirm();
