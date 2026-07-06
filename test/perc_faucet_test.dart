import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/services/perc_faucet.dart';

void main() {
  test('percent chance reward is two-digit outcome over 100 PERC', () {
    final reward = PercFaucet.computeAnalysisReward(outcomeScore: 42.7);
    expect(reward.twoDigitOutcome, 43);
    expect(reward.outcomeFractionLabel, '43/100');
    expect(reward.total, PercAmount.fromPerc(0.43));
    expect(reward.total.displayFixed8, '0.43000000');
  });

  test('SCS reward uses refined score as two-digit xx/100', () {
    final reward = PercFaucet.computeAnalysisReward(outcomeScore: 67.2);
    expect(reward.twoDigitOutcome, 67);
    expect(reward.total, PercAmount.fromPerc(0.67));
  });

  test('higher outcomes credit more PERC than lower outcomes', () {
    final low = PercFaucet.computeAnalysisReward(outcomeScore: 10);
    final high = PercFaucet.computeAnalysisReward(outcomeScore: 80);
    expect(high.total.microUnits, greaterThan(low.total.microUnits));
    expect(high.twoDigitOutcome, 80);
    expect(low.twoDigitOutcome, 10);
  });
}