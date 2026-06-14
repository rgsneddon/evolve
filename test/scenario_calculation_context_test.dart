import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/chronoflux_weight_construal.dart';
import 'package:evolve/services/input_parser.dart';
import 'package:evolve/services/scenario_calculation_context.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const construal = ChronofluxWeightConstrual();
  const parser = InputParser();
  const engine = EvolveEngine();

  test('field prose does not change weights — field presence does', () {
    const base = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    const withFields = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High shear from polarized protests and rallies.',
      resistanceText: 'Institutional scepticism rising.',
      flowText: 'Trust erosion where nuance is absent.',
    );

    final wBase = parser.enrich(base).constructs.map((c) => c.weight).toList();
    final wFields =
        parser.enrich(withFields).constructs.map((c) => c.weight).toList();

    expect(wFields[2], greaterThan(wBase[2]));
    expect(wFields[3], greaterThan(wBase[3]));
    expect(wFields[1], greaterThan(wBase[1]));
    expect(construal.construe(withFields).reasonKeys, contains('weight_reason_shear'));
  });

  test('REGRESSIVE lean raises σ/Iτ weights vs PROGRESSIVE for same context', () {
    const input = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    final ctx = ScenarioCalculationContext.from(input: input);
    final reg = construal.construeFromContext(
      ScenarioCalculationContext(
        regionId: ctx.regionId,
        hasPosedQuestion: ctx.hasPosedQuestion,
        hasTopic: ctx.hasTopic,
        frame: ctx.frame,
        polarity: ctx.polarity,
        eventClass: ctx.eventClass,
        horizonDays: ctx.horizonDays,
        fields: ctx.fields,
        lean: 'REGRESSIVE',
      ),
    );
    final prog = construal.construeFromContext(
      ScenarioCalculationContext(
        regionId: ctx.regionId,
        hasPosedQuestion: ctx.hasPosedQuestion,
        hasTopic: ctx.hasTopic,
        frame: ctx.frame,
        polarity: ctx.polarity,
        eventClass: ctx.eventClass,
        horizonDays: ctx.horizonDays,
        fields: ctx.fields,
        lean: 'PROGRESSIVE',
      ),
    );

    expect(reg.normalized[2], greaterThan(prog.normalized[2]));
    expect(reg.normalized[3], greaterThan(prog.normalized[3]));
    expect(prog.normalized[1], greaterThan(reg.normalized[1]));
    expect(reg.reasonKeys, contains('weight_reason_lean_regressive'));
    expect(prog.reasonKeys, contains('weight_reason_lean_progressive'));
  });

  test('different posed questions change context weights without field content', () {
    final unrest = construal.construe(const ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    ));
    final policy = construal.construe(const ScenarioInput(
      posedQuestion: 'Will the government publish new policy this month?',
    ));

    expect(unrest.normalized, isNot(equals(policy.normalized)));
    expect(unrest.reasonKeys, contains('weight_reason_context_unrest'));
    expect(policy.reasonKeys, contains('weight_reason_context_institutional'));
  });

  test('field prose alone does not change SCS — explicit scs=N or variable semantics do', () {
    const contextual = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    );
    const withProse = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'High polarisation and severe friction everywhere.',
    );
    const withExplicit = ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
      shearText: 'scs=72',
    );

    final a = parser.enrich(contextual);
    final b = parser.enrich(withProse);
    final c = parser.enrich(withExplicit);

    expect(b.shear.scs, isNot(equals(a.shear.scs)));
    expect(c.shear.scs, 72);
  });

  test('enriched pipeline applies lean-dependent weights in analyze', () {
    final result = engine.analyze(const ScenarioInput(
      posedQuestion:
          'What is the chance of sporadic civil unrest in the UK near-term?',
    ));

    expect(result.grokStyleReply, contains('lean-driven'));
    expect(result.grokStyleReply, contains('REGRESSIVE lean — σ/Iτ friction weighted'));
  });

  test('regional context shifts weights without field content', () {
    const input = ScenarioInput(
      posedQuestion: 'Chance of unrest near-term?',
    );
    final global = construal.construe(input, regionId: 'global');
    final uk = construal.construe(
      input,
      regionId: 'uk_ireland',
    );

    expect(uk.normalized, isNot(equals(global.normalized)));
    expect(uk.reasonKeys, contains('weight_reason_regional'));
  });
}