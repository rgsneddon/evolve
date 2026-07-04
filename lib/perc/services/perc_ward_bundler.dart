import '../models/perc_side_chain.dart';
import '../perc_chain_constants.dart';

/// A ward bundles exactly [PercChainConstants.microblocksPerWard] microblocks.
class PercWardView {
  const PercWardView({
    required this.microblocksPerWard,
    required this.wardsPerSealCycle,
    required this.completedWardsInCycle,
    required this.microblocksInCurrentWard,
    required this.totalWardsEver,
    required this.pendingMicroblocks,
    required this.microblocksPerBlock,
  });

  final int microblocksPerWard;
  final int wardsPerSealCycle;
  final int completedWardsInCycle;
  final int microblocksInCurrentWard;
  final int totalWardsEver;
  final int pendingMicroblocks;
  final int microblocksPerBlock;

  /// 0-based index of the ward currently accumulating microblocks.
  int get currentWardIndex => completedWardsInCycle.clamp(0, wardsPerSealCycle);

  double get currentWardProgress =>
      microblocksPerWard > 0 ? microblocksInCurrentWard / microblocksPerWard : 0;

  double get sealCycleWardProgress =>
      wardsPerSealCycle > 0 ? completedWardsInCycle / wardsPerSealCycle : 0;

  bool isWardComplete(int wardIndex) => wardIndex < completedWardsInCycle;

  bool isWardInProgress(int wardIndex) =>
      wardIndex == completedWardsInCycle && microblocksInCurrentWard > 0;

  double wardFillRatio(int wardIndex) {
    if (isWardComplete(wardIndex)) return 1;
    if (isWardInProgress(wardIndex)) return currentWardProgress;
    return 0;
  }
}

/// Maps microblock counts into ward bundles for the dynamic explorer.
class PercWardBundler {
  const PercWardBundler._();

  static PercWardView fromSideChain(PercSideChainState side) =>
      fromCounts(
        pendingMicroblocks: side.pendingMicroblocks,
        totalMicroblocks: side.microblockHeight,
        microblocksPerBlock: side.microblocksPerBlock,
      );

  static PercWardView fromCounts({
    required int pendingMicroblocks,
    required int totalMicroblocks,
    required int microblocksPerBlock,
    int? microblocksPerWard,
  }) {
    final perWard = microblocksPerWard ?? PercChainConstants.microblocksPerWard;
    final wardsPerCycle = perWard > 0 ? microblocksPerBlock ~/ perWard : 0;
    final pending = pendingMicroblocks.clamp(0, microblocksPerBlock);
    final completed = perWard > 0 ? pending ~/ perWard : 0;
    final inCurrent = perWard > 0 ? pending % perWard : 0;

    return PercWardView(
      microblocksPerWard: perWard,
      wardsPerSealCycle: wardsPerCycle,
      completedWardsInCycle: completed,
      microblocksInCurrentWard: inCurrent,
      totalWardsEver: perWard > 0 ? totalMicroblocks ~/ perWard : 0,
      pendingMicroblocks: pending,
      microblocksPerBlock: microblocksPerBlock,
    );
  }
}