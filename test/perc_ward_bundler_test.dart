import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_shard_density.dart';
import 'package:evolve/perc/services/perc_ward_bundler.dart';

void main() {
  test('10,000 microblocks form one ward', () {
    expect(PercChainConstants.microblocksPerWard, 10000);
    final view = PercWardBundler.fromCounts(
      pendingMicroblocks: 10000,
      totalMicroblocks: 25000,
      microblocksPerBlock: PercChainConstants.microblocksPerBlock,
    );
    expect(view.completedWardsInCycle, 1);
    expect(view.microblocksInCurrentWard, 0);
    expect(view.totalWardsEver, 2);
  });

  test('seal cycle contains 10,000 wards', () {
    final view = PercWardBundler.fromCounts(
      pendingMicroblocks: 0,
      totalMicroblocks: 0,
      microblocksPerBlock: PercChainConstants.microblocksPerBlock,
    );
    expect(view.wardsPerSealCycle, 10000);
  });

  test('partial ward tracks in-progress microblocks', () {
    final view = PercWardBundler.fromCounts(
      pendingMicroblocks: 15500,
      totalMicroblocks: 15500,
      microblocksPerBlock: PercChainConstants.microblocksPerBlock,
    );
    expect(view.completedWardsInCycle, 1);
    expect(view.microblocksInCurrentWard, 5500);
    expect(view.currentWardIndex, 1);
    expect(view.wardFillRatio(1), closeTo(0.55, 0.001));
  });

  test('ward density field maps one cell per ward', () async {
    final wards = PercWardBundler.fromCounts(
      pendingMicroblocks: 30000,
      totalMicroblocks: 30000,
      microblocksPerBlock: PercChainConstants.microblocksPerBlock,
    );
    final field = await PercShardDensity.buildForWards(wards: wards);
    expect(field.totalShards, 10000);
    expect(field.litShards, 3);
    expect(field.density.fold<int>(0, (a, b) => a + b), 10000);
  });
}