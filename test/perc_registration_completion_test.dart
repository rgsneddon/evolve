import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_alignment.dart';
import 'package:evolve/perc/services/perc_registration_completion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decide publishes when seed reachable and aligned', () {
    final action = PercRegistrationCompletion.decide(
      const PercRegistrationSeedAdoption(
        seedReachable: true,
        isAligned: true,
        seedHeight: 4,
        seedTipHash: 'tip-a',
        seedChainId: PercChainConstants.evolutionaryChainId,
      ),
    );
    expect(action.publishNow, isTrue);
    expect(action.markAwaiting, isFalse);
    expect(action.offlineHonest, isFalse);
  });

  test('decide awaits when seed reachable but misaligned', () {
    final action = PercRegistrationCompletion.decide(
      const PercRegistrationSeedAdoption(
        seedReachable: true,
        isAligned: false,
        seedHeight: 4,
        seedTipHash: 'tip-a',
        seedChainId: PercChainConstants.evolutionaryChainId,
      ),
    );
    expect(action.publishNow, isFalse);
    expect(action.markAwaiting, isTrue);
    expect(action.offlineHonest, isFalse);
  });

  test('decide is offline-honest when seed unreachable', () {
    final action = PercRegistrationCompletion.decide(
      const PercRegistrationSeedAdoption(
        seedReachable: false,
        isAligned: false,
        seedHeight: 0,
        seedTipHash: '',
        seedChainId: PercChainConstants.evolutionaryChainId,
      ),
    );
    expect(action.publishNow, isFalse);
    expect(action.markAwaiting, isFalse);
    expect(action.offlineHonest, isTrue);
  });
}