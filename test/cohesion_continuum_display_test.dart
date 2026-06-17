import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:evolve/models/scenario_input.dart';

void main() {
  test('cohesion continuum subtitle uses calibrated percent chance not continuum split', () {
    const engine = EvolveEngine();
    const input = ScenarioInput(
      posedQuestion:
          'What is the social cohesion trajectory for protest coverage in Glasgow?',
      vortexText: 'Polarised party responses dominate the narrative.',
      shearText: 'High σ bias between establishment and grassroots frames.',
      resistanceText: 'Iτ drag from delayed institutional follow-through.',
      flowText: 'Jμ trust transport remains uneven across wards.',
    );

    final cohesion = engine.analyze(
      input,
      mode: AnalysisMode.cohesionScore,
      locale: LocaleConfig.defaults,
    );
    final percent = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: LocaleConfig.defaults,
    );
    final out = LocalizedOutput.of(LocaleConfig.defaults);
    final headlinePct = out.cohesionContinuumHeadlinePercent(cohesion.percentChance);
    final subtitle = out.cohesionContinuumSubtitle(
      lean: out.leanLabel(cohesion.core.lean),
      pct: headlinePct,
    );

    expect(cohesion.percentChance, percent.percentChance);
    expect(headlinePct, cohesion.percentChance.round());
    expect(headlinePct, inInclusiveRange(8, 92));
    expect(subtitle, '${out.leanLabel(cohesion.core.lean)} — $headlinePct%');

    final heuristic = EvolveEngine.heuristicPercentChance(
      regressivePct: cohesion.partTwo.regressivePct,
      refinedScs: cohesion.partTwo.refinedScs,
      shearScs: cohesion.core.shearScs,
    );
    expect(cohesion.forecast.heuristicPercent, closeTo(heuristic, 0.001));
    expect(
      headlinePct,
      isNot(equals(cohesion.core.regressivePct.round())),
      reason: 'must not show raw THE CONTINUUM regressive share',
    );
  });
}