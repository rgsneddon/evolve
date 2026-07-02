import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/services/perc_faucet.dart';

void main() {
  test('scenario base reward is 0.00000050 PERC', () {
    final reward = PercFaucet.computeScenarioReward(percentChance: 0);
    expect(reward.base, PercAmount.scenarioBaseReward);
    expect(reward.base.displayFixed8, '0.00000050');
  });

  test('faucet bonus scales with percent chance outcome', () {
    final low = PercFaucet.computeScenarioReward(percentChance: 10);
    final high = PercFaucet.computeScenarioReward(percentChance: 80);
    expect(high.total.microUnits, greaterThan(low.total.microUnits));
    expect(high.bonus.microUnits, 80);
  });
}