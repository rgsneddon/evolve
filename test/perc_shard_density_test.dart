import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_shard_density.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every microblock shard into the density field', () async {
    const sampleTotal = 100000;
    const lit = 42000;
    final field = await PercShardDensity.build(
      totalShards: sampleTotal,
      litShards: lit,
      angularBins: 120,
      radialBins: 80,
    );

    final sum = field.density.fold<int>(0, (a, b) => a + b);
    final litSum = field.litDensity.fold<int>(0, (a, b) => a + b);

    expect(sum, sampleTotal);
    expect(litSum, lit);
  });

  test('full chain uses 100M shard constant', () {
    expect(PercChainConstants.microblocksPerBlock, 100000000);
  });
}