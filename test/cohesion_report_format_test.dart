import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();

  test('cohesion report follows MarkdownBin bullet layout', () {
    const input = ScenarioInput(
      topic: 'John Swinney statement on 9 June 2026 protests',
      posedQuestion:
          'What is cohesion after the First Minister condemns protests in Glasgow, Edinburgh, and Ayr?',
      vortexText:
          'Blanket condemnation of all protests as unacceptable scenes of racism and intimidation.',
      shearText: 'Pushback on narrative control and selective condemnation.',
      resistanceText:
          'Strong institutional legitimacy vs. growing public skepticism.',
      flowText: 'Trajectory toward trust erosion where nuance is absent.',
    );
    final result = engine.analyze(input);
    final out = LocalizedOutput.of(LocaleConfig.defaults);
    final report = result.cohesionReport;

    expect(report, contains('# SSUCF Analysis:'));
    expect(report, contains('Social Cohesion Analysis under Chronoflux-derived'));
    expect(report, contains(out.strings.t('cohesion_part_one')));
    expect(report, contains('* Core input:'));
    expect(report, contains('* Pushback on narrative control'));
    expect(report, contains('Weighted Overall SCS'));
    expect(report, contains(out.cohesionConclusionHeading));
    final conclusionIdx = report.indexOf(out.cohesionConclusionHeading);
    final weightedInConclusionIdx = report.indexOf(
      'Weighted Overall SCS',
      conclusionIdx,
    );
    expect(weightedInConclusionIdx, greaterThan(conclusionIdx));
    expect(report, isNot(contains('THE CONTINUUM — Calibrated Forecast')));
    expect(report, isNot(contains('High elite alignment')));
    expect(report, isNot(contains('Elite statements on')));
    expect(report, contains(result.partTwo.shearRefinement));
    expect(report, contains('Final Summary:'));
    expect(report, contains(out.cohesionCycleComplete));
    expect(report, contains('SSUCF Cycle Complete'));
  });
}