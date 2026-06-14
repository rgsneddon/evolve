import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('regressive unrest shifts toward PROGRESSIVE not amplification', () {
    final result = engine.analyze(
      const ScenarioInput(
        vortexText: 'What is the chance of sporadic civil unrest near-term?',
        shearText: 'High polarisation in media.',
      ),
      mode: AnalysisMode.percentChance,
    );

    expect(result.core.lean, 'REGRESSIVE');
    final p3 = result.partThreeConclusion;
    expect(p3.headline.toUpperCase(), contains('PROGRESSIVE'));
    expect(p3.projectedImpact.toUpperCase(), contains('PROGRESSIVE'));
    expect(p3.contextLine.toUpperCase(), contains('REGRESSIVE'));

    final current = result.percentChance.round();
    final projectedMatch = RegExp(r'~(\d+)%').allMatches(p3.targetLabel).toList();
    expect(projectedMatch.length, greaterThanOrEqualTo(2));
    final projected = int.parse(projectedMatch.last.group(1)!);
    expect(projected, lessThan(current));
  });

  test('cohesion mode targets SCS improvement', () {
    final result = engine.analyze(
      const ScenarioInput(
        vortexText: 'Minister statement on city protests.',
        shearText: 'Polarized pushback.',
      ),
      mode: AnalysisMode.cohesionScore,
    );

    final p3 = result.partThreeConclusion;
    expect(p3.headline.toUpperCase(), contains('SCS'));
    expect(p3.targetLabel, contains('→'));
    expect(p3.actions.length, 5);
    expect(p3.actions.every((a) => a.rationale.isNotEmpty), isTrue);
  });
}