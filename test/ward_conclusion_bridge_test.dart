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

    final restored = WardConclusionLink.fromJson(link.toJson());
    expect(restored.title, link.title);
    expect(restored.analysisMode, link.analysisMode);
    expect(restored.outcomeScore, link.outcomeScore);
    expect(restored.grokEnriched, link.grokEnriched);
  });
}