import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/models/ward_conclusion_link.dart';
import 'package:evolve/perc/services/ward_conclusion_bridge.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  const engine = EvolveEngine();
  const locale = LocaleConfig.defaults;
  final strings = AppLocalizations.of(locale);

  test('bridge builds readable ward link from percent chance conclusion', () {
    const input = ScenarioInput(
      topic: 'Local economy',
      posedQuestion: 'Will the ward approve the pocket park this year?',
    );
    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    final link = WardConclusionBridge.build(
      result: result,
      input: input,
      mode: AnalysisMode.percentChance,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: false,
    );

    expect(link.title, contains('pocket park'));
    expect(link.wardName, isNotEmpty);
    expect(link.summary, isNotEmpty);
    expect(link.voteCommentPrefill, contains('Evolve analysis'));
    expect(link.analysisMode, AnalysisMode.percentChance);
    expect(link.outcomeScore, greaterThan(0));
    expect(link.conclusionExcerpt, isNotEmpty);
    expect(link.grokEnriched, isFalse);
    expect(link.matchKey, WardConclusionLink.normalizeTitle(link.title));
  });

  test('bridge includes grok snippet when construal enabled', () {
    const input = ScenarioInput(
      posedQuestion: 'Will transit funding pass the council vote?',
    );
    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    final link = WardConclusionBridge.build(
      result: result,
      input: input,
      mode: AnalysisMode.percentChance,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: true,
    );

    if (result.grokStyleReply.trim().isNotEmpty) {
      expect(link.grokEnriched, isTrue);
      expect(link.summary, contains('Grok construal'));
    }
  });

  test('buildDual combines percent chance and SCS in summary and comment', () {
    const input = ScenarioInput(
      posedQuestion: 'Should the ward fund the new community garden?',
    );
    final percentResult = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );
    final cohesionResult = engine.analyze(
      input,
      mode: AnalysisMode.cohesionScore,
      locale: locale,
    );

    final link = WardConclusionBridge.buildDual(
      percentResult: percentResult,
      cohesionResult: cohesionResult,
      input: input,
      locale: locale,
      strings: strings,
    );

    expect(link.dualAnalysis, isTrue);
    expect(link.percentChance, percentResult.percentChance);
    expect(link.refinedScs, cohesionResult.core.refinedScs);
    expect(link.summary, contains(strings.t('ward_dual_summary_header')));
    expect(link.summary, contains('${percentResult.percentChance.round()}%'));
    expect(link.summary, contains('${cohesionResult.core.refinedScs.round()}/100 SCS'));
    expect(link.voteCommentPrefill, contains(strings.t('ward_dual_vote_prefill_header')));
  });

  test('buildBestEffortDual runs missing mode from single Evolve result', () {
    const input = ScenarioInput(
      posedQuestion: 'Will the farmers market permit be renewed?',
    );
    final percentResult = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );

    final link = WardConclusionBridge.buildBestEffortDual(
      currentResult: percentResult,
      currentMode: AnalysisMode.percentChance,
      input: input,
      locale: locale,
      strings: strings,
      percentResult: percentResult,
      cohesionResult: null,
    );

    expect(link.dualAnalysis, isTrue);
    expect(link.percentChance, percentResult.percentChance);
    expect(link.refinedScs, isNotNull);
    expect(link.summary, contains(strings.t('ward_dual_summary_header')));
  });

  test('enrichLinkToDual upgrades single-mode conclusion link', () {
    const input = ScenarioInput(
      posedQuestion: 'Should the ward adopt the noise ordinance?',
    );
    final result = engine.analyze(
      input,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );
    final single = WardConclusionBridge.build(
      result: result,
      input: input,
      mode: AnalysisMode.percentChance,
      locale: locale,
      strings: strings,
    );

    expect(single.dualAnalysis, isFalse);

    final enriched = WardConclusionBridge.enrichLinkToDual(
      seed: single,
      locale: locale,
      strings: strings,
    );

    expect(enriched.dualAnalysis, isTrue);
    expect(enriched.title, single.title);
    expect(enriched.conclusionExcerpt, single.conclusionExcerpt);
    expect(enriched.percentChance, isNotNull);
    expect(enriched.refinedScs, isNotNull);
    expect(enriched.summary, contains('${enriched.percentChance!.round()}%'));
    expect(enriched.summary, contains('${enriched.refinedScs!.round()}/100 SCS'));
  });

  test('buildFromScenario with grok construal marks link grok enriched', () {
    const input = ScenarioInput(
      posedQuestion: 'Will the night market license be renewed?',
    );
    final plain = WardConclusionBridge.buildFromScenario(
      input: input,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: false,
    );
    final grok = WardConclusionBridge.buildFromScenario(
      input: input,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: true,
    );

    expect(plain.grokEnriched, isFalse);
    expect(grok.grokEnriched, isTrue);
    expect(grok.summary, contains(strings.t('ward_conclusion_link_grok_note')));
  });

  test('buildFromScenario produces dual link', () {
    const input = ScenarioInput(
      posedQuestion: 'Will the library expansion bond pass?',
    );
    final link = WardConclusionBridge.buildFromScenario(
      input: input,
      locale: locale,
      strings: strings,
    );

    expect(link.dualAnalysis, isTrue);
    expect(link.percentChance, isNotNull);
    expect(link.refinedScs, isNotNull);
    expect(link.title, contains('library expansion'));
  });

  test('bridge round-trips through json', () {
    const input = ScenarioInput(posedQuestion: 'Should we extend library hours?');
    final result = engine.analyze(
      input,
      mode: AnalysisMode.cohesionScore,
      locale: locale,
    );
    final link = WardConclusionBridge.build(
      result: result,
      input: input,
      mode: AnalysisMode.cohesionScore,
      locale: locale,
      strings: strings,
    );

    final dual = WardConclusionBridge.buildDual(
      percentResult: engine.analyze(
        input,
        mode: AnalysisMode.percentChance,
        locale: locale,
      ),
      cohesionResult: engine.analyze(
        input,
        mode: AnalysisMode.cohesionScore,
        locale: locale,
      ),
      input: input,
      locale: locale,
      strings: strings,
    );
    final restored = WardConclusionLink.fromJson(dual.toJson());
    expect(restored.title, dual.title);
    expect(restored.dualAnalysis, isTrue);
    expect(restored.percentChance, dual.percentChance);
    expect(restored.refinedScs, dual.refinedScs);
    expect(restored.grokEnriched, dual.grokEnriched);
  });
}