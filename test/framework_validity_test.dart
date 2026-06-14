import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/l10n/localized_output.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/construct_input.dart';
import 'package:evolve/models/framework_spec.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/chronoflux_weight_construal.dart';
import 'package:evolve/services/input_parser.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();
  const parser = InputParser();
  const weightConstrual = ChronofluxWeightConstrual();

  const scenarios = [
    ScenarioInput(
      posedQuestion: 'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High shear from polarized protests and rallies.',
    ),
    ScenarioInput(
      posedQuestion: 'Will the mayor win re-election in 2027?',
      topic: 'Municipal politics',
      flowText: 'Moderate trust transport through local media.',
    ),
    ScenarioInput(
      posedQuestion: 'How likely is a recession in the eurozone this year?',
      resistanceText: 'Institutional inertia at ECB level.',
    ),
    ScenarioInput(
      posedQuestion: 'Can protests in Glasgow escalate into sustained disorder?',
      vortexText: 'Elite framing around selective condemnation.',
      shearText: 'scs=72',
      resistanceText: 'scs=48',
      flowText: 'low',
    ),
    ScenarioInput(
      posedQuestion: 'Describe cohesion trajectory for Japan after demographic shock.',
      topic: 'Demographics',
    ),
  ];

  group('FrameworkSpec canonical constructs', () {
    test('construct order matches engine array [ρt, Jμ, σ, Iτ, ω]', () {
      const input = ScenarioInput(
        posedQuestion: 'Test question?',
        continuum: ConstructInput(scs: 50, weight: 1),
        flow: ConstructInput(scs: 51, weight: 2),
        shear: ConstructInput(scs: 52, weight: 3),
        resistance: ConstructInput(scs: 53, weight: 4),
        vortex: ConstructInput(scs: 54, weight: 5),
      );
      final keys = ['continuum', 'flow', 'shear', 'resistance', 'vortex'];
      for (var i = 0; i < 5; i++) {
        expect(FrameworkSpec.constructs[i], contains(_symbolFor(keys[i])));
      }
      expect(input.constructs.map((c) => c.scs).toList(),
          [50, 51, 52, 53, 54]);
    });
  });

  group('Weight construal invariants', () {
    test('normalized weights always sum to 1', () {
      for (final s in scenarios) {
        final w = weightConstrual.construe(s);
        final sum = w.normalized.fold(0.0, (a, x) => a + x);
        expect(sum, closeTo(1.0, 1e-9), reason: s.posedQuestion);
      }
    });

    test('supplied σ field raises weight vs blank — prose alone does not', () {
      const blank = ScenarioInput(
        posedQuestion: 'Will protests spread in the capital?',
      );
      const withShear = ScenarioInput(
        posedQuestion: 'Will protests spread in the capital?',
        shearText: 'Polarized rallies and grievance framing.',
      );
      final wBlank = weightConstrual.construe(blank).normalized[2];
      final wShear = weightConstrual.construe(withShear).normalized[2];
      expect(wShear, greaterThan(wBlank));
      expect(
        weightConstrual.construe(withShear).reasonKeys,
        contains('weight_reason_shear'),
      );
    });

    test('enriched input applies different weights when different fields supplied', () {
      const a = ScenarioInput(
        posedQuestion: 'Economic downturn in Brazil?',
        flowText: 'Trust erosion in commodity regions.',
      );
      const b = ScenarioInput(
        posedQuestion: 'Economic downturn in Brazil?',
        resistanceText: 'Central bank institutional skepticism.',
      );
      final wa = parser.enrich(a).constructs.map((c) => c.weight).toList();
      final wb = parser.enrich(b).constructs.map((c) => c.weight).toList();
      expect(wa[1], greaterThan(wb[1]));
      expect(wb[3], greaterThan(wa[3]));
    });
  });

  group('Hydrodynamic core invariants', () {
    for (final scenario in scenarios) {
      test('pipeline valid for: ${scenario.posedQuestion.substring(0, math.min(40, scenario.posedQuestion.length))}…',
          () {
        final result = engine.analyze(scenario);
        final core = result.core;
        final two = result.partTwo;

        expect(result.partTwoRan, isTrue);
        expect(result.partOne.vortex, isNotEmpty);
        expect(result.partTwo.expandedVortex, isNotEmpty);
        expect(result.partThree.interventions, isNotEmpty);

        expect(core.progressivePct + core.regressivePct, closeTo(100.0, 0.01));
        expect(two.progressivePct + two.regressivePct, closeTo(100.0, 0.01));

        expect(core.refinedScs, inInclusiveRange(20, 87));
        expect(result.percentChance, inInclusiveRange(8, 92));
        expect(core.continuumScs, inInclusiveRange(30, 80));

        for (final scs in [
          core.flowScs,
          core.shearScs,
          core.resistanceScs,
          core.vortexScs,
        ]) {
          expect(scs, inInclusiveRange(0, 100));
        }

        if (core.netMomentum >= 0) {
          expect(core.lean, 'PROGRESSIVE');
        } else {
          expect(core.lean, 'REGRESSIVE');
        }

        expect(result.partThree.withoutLeversScs, closeTo(core.refinedScs, 0.01));
        expect(
          result.partThree.withLeversMin,
          lessThanOrEqualTo(result.partThree.withLeversMax),
        );
        expect(result.grokStyleReply.toLowerCase(), isNot(contains('betting odds')));
        expect(result.continuumConclusion, contains('Outcome registry'));
        expect(result.forecast.sampleSize, greaterThan(0));
        expect(result.percentChance, result.forecast.calibratedPercent);
        final out = LocalizedOutput.of(LocaleConfig.defaults);
        expect(result.cohesionReport, contains(out.strings.t('cohesion_part_one')));
        expect(result.cohesionReport, contains(out.strings.t('cohesion_part_two')));
        expect(result.cohesionReport, contains(out.strings.t('cohesion_part_three')));
      });
    }
  });

  group('Cross-mode and determinism', () {
    test('percent and cohesion modes share identical hydrodynamic core', () {
      const input = ScenarioInput(
        posedQuestion: 'Chance of unrest in Paris this summer?',
        shearText: 'High polarization around policing.',
      );
      final pct = engine.analyze(input, mode: AnalysisMode.percentChance);
      final coh = engine.analyze(input, mode: AnalysisMode.cohesionScore);
      expect(pct.core.refinedScs, coh.core.refinedScs);
      expect(pct.core.progressivePct, coh.core.progressivePct);
      expect(pct.percentChance, coh.percentChance);
    });

    test('same input yields deterministic output', () {
      const input = ScenarioInput(
        posedQuestion: 'Will inflation fall below 2% in 2026?',
      );
      final a = engine.analyze(input);
      final b = engine.analyze(input);
      expect(a.percentChance, b.percentChance);
      expect(a.core.refinedScs, b.core.refinedScs);
      expect(a.grokStyleReply, b.grokStyleReply);
    });

    test('different questions produce divergent results', () {
      const a = ScenarioInput(
        posedQuestion: 'Will solar adoption exceed 50% in Germany?',
      );
      const b = ScenarioInput(
        posedQuestion: 'Will civil war break out in Region X?',
      );
      final ra = engine.analyze(a);
      final rb = engine.analyze(b);
      expect(
        ra.percentChance == rb.percentChance &&
            ra.core.refinedScs == rb.core.refinedScs,
        isFalse,
      );
    });
  });

  group('Locale robustness', () {
    test('Spanish locale preserves core invariants', () {
      const input = ScenarioInput(
        posedQuestion: '¿Cuál es la probabilidad de protestas en Madrid?',
      );
      final result = engine.analyze(
        input,
        locale: const LocaleConfig(regionId: 'spain', languageCode: 'es'),
      );
      expect(result.core.progressivePct + result.core.regressivePct,
          closeTo(100.0, 0.01));
      expect(result.percentChance, inInclusiveRange(8, 92));
      final es = AppLocalizations.of(
        const LocaleConfig(regionId: 'spain', languageCode: 'es'),
      );
      expect(result.cohesionReport, contains(es.t('cohesion_part_one')));
      expect(result.cohesionReport, contains(es.t('cohesion_part_two')));
      expect(result.cohesionReport, contains(es.t('cohesion_part_three')));
    });
  });

  group('Explicit SCS parsing', () {
    test('scs=N in text is honoured and bounded', () {
      const input = ScenarioInput(
        posedQuestion: 'Test explicit scores?',
        shearText: 'scs=150',
        resistanceText: 'scs=5',
      );
      final enriched = parser.enrich(input);
      expect(enriched.shear.scs, 100);
      expect(enriched.resistance.scs, 5);
    });
  });
}

String _symbolFor(String key) => switch (key) {
      'continuum' => 'ρt',
      'flow' => 'Jμ',
      'shear' => 'σ',
      'resistance' => 'Iτ',
      'vortex' => 'ω',
      _ => '',
    };