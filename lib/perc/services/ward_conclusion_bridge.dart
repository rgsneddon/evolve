import '../../l10n/app_localizations.dart';
import '../../l10n/localized_output.dart';
import '../../models/analysis_mode.dart';
import '../../models/evolve_result.dart';
import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../../services/conclusion_explainer.dart';
import '../../services/evolve_engine.dart';
import '../models/ward_conclusion_link.dart';
import 'ward_grok_construal.dart';

/// Builds ward-voting payloads readable by the Community Ward Voting dapp.
class WardConclusionBridge {
  const WardConclusionBridge._();

  static const int _maxTitleLen = 120;
  static const int _maxSummaryLen = 2000;
  static const int _maxCommentLen = 2000;
  static const int _maxExcerptLen = 600;
  static const int _maxGrokSnippetLen = 400;

  static WardConclusionLink build({
    required EvolveResult result,
    required ScenarioInput input,
    required AnalysisMode mode,
    required LocaleConfig locale,
    required AppLocalizations strings,
    String? conclusionExcerptOverride,
    bool grokConstrualEnabled = false,
  }) {
    final output = LocalizedOutput.of(locale);
    final question = _firstNonEmpty([
      input.posedQuestionLine,
      input.scenarioQuery,
      input.topic,
    ]);
    final topic = input.topic.trim();
    final wardName = output.regionName(locale.regionId);
    final excerpt = _truncate(
      conclusionExcerptOverride ?? _conclusionExcerpt(result, mode, locale),
      _maxExcerptLen,
    );
    final grokSnippet = grokConstrualEnabled && result.grokStyleReply.trim().isNotEmpty
        ? _grokSnippet(result.grokStyleReply, locale)
        : '';
    final outcomeScore = mode == AnalysisMode.percentChance
        ? result.percentChance
        : result.core.refinedScs;
    final outcomeLabel = mode == AnalysisMode.percentChance
        ? '${outcomeScore.round()}%'
        : '${outcomeScore.round()}/100 SCS';
    final modeLabel = mode == AnalysisMode.percentChance
        ? strings.t('mode_percent')
        : strings.t('mode_cohesion');

    final summary = _truncate(
      _buildSummary(
        excerpt: excerpt,
        modeLabel: modeLabel,
        outcomeLabel: outcomeLabel,
        lean: output.leanLabel(result.core.lean),
        grokSnippet: grokSnippet,
        grokEnriched: grokSnippet.isNotEmpty,
        strings: strings,
      ),
      _maxSummaryLen,
    );

    final voteComment = _truncate(
      _buildVoteComment(
        question: question,
        modeLabel: modeLabel,
        outcomeLabel: outcomeLabel,
        lean: output.leanLabel(result.core.lean),
        excerpt: excerpt,
        grokSnippet: grokSnippet,
        strings: strings,
      ),
      _maxCommentLen,
    );

    return WardConclusionLink(
      title: _truncate(_proposalTitle(question, topic, excerpt), _maxTitleLen),
      summary: summary,
      wardName: wardName,
      voteCommentPrefill: voteComment,
      analysisMode: mode,
      outcomeScore: outcomeScore,
      conclusionExcerpt: excerpt,
      grokEnriched: grokSnippet.isNotEmpty,
      posedQuestion: question,
      topic: topic,
    );
  }

  /// Combines percent chance and SCS into one ward-voting payload.
  static WardConclusionLink buildDual({
    required EvolveResult percentResult,
    required EvolveResult cohesionResult,
    required ScenarioInput input,
    required LocaleConfig locale,
    required AppLocalizations strings,
    String? conclusionExcerptOverride,
    bool grokConstrualEnabled = false,
  }) {
    final output = LocalizedOutput.of(locale);
    final question = _firstNonEmpty([
      input.posedQuestionLine,
      input.scenarioQuery,
      input.topic,
    ]);
    final topic = input.topic.trim();
    final wardName = output.regionName(locale.regionId);
    final excerpt = _truncate(
      conclusionExcerptOverride ??
          _dualConclusionExcerpt(percentResult, cohesionResult, locale),
      _maxExcerptLen,
    );
    final grokReply = percentResult.grokStyleReply.trim().isNotEmpty
        ? percentResult.grokStyleReply
        : cohesionResult.grokStyleReply;
    final grokSnippet = grokConstrualEnabled && grokReply.isNotEmpty
        ? _grokSnippet(grokReply, locale)
        : '';
    final percentLabel = _percentLine(
      percentResult,
      strings.t('mode_percent'),
    );
    final scsLabel = _scsLine(
      cohesionResult,
      output,
      strings.t('mode_cohesion'),
    );

    final summary = _truncate(
      _buildDualSummary(
        percentLine: percentLabel,
        scsLine: scsLabel,
        excerpt: excerpt,
        grokSnippet: grokSnippet,
        grokEnriched: grokSnippet.isNotEmpty,
        strings: strings,
      ),
      _maxSummaryLen,
    );

    final voteComment = _truncate(
      _buildDualVoteComment(
        question: question,
        percentLine: percentLabel,
        scsLine: scsLabel,
        excerpt: excerpt,
        grokSnippet: grokSnippet,
        strings: strings,
      ),
      _maxCommentLen,
    );

    return WardConclusionLink(
      title: _truncate(_proposalTitle(question, topic, excerpt), _maxTitleLen),
      summary: summary,
      wardName: wardName,
      voteCommentPrefill: voteComment,
      analysisMode: AnalysisMode.percentChance,
      outcomeScore: percentResult.percentChance,
      conclusionExcerpt: excerpt,
      grokEnriched: grokSnippet.isNotEmpty,
      posedQuestion: question,
      topic: topic,
      dualAnalysis: true,
      percentChance: percentResult.percentChance,
      percentPhrase: percentResult.percentPhrase,
      refinedScs: cohesionResult.core.refinedScs,
      scsLean: output.leanLabel(cohesionResult.core.lean),
    );
  }

  /// Builds a dual link from Evolve, running the missing mode when only one is saved.
  static WardConclusionLink buildBestEffortDual({
    required EvolveResult currentResult,
    required AnalysisMode currentMode,
    required ScenarioInput input,
    required LocaleConfig locale,
    required AppLocalizations strings,
    EvolveResult? percentResult,
    EvolveResult? cohesionResult,
    String? conclusionExcerptOverride,
    bool grokConstrualEnabled = false,
    EvolveEngine engine = const EvolveEngine(),
  }) {
    var pct = percentResult;
    var scs = cohesionResult;
    if (pct == null && currentMode == AnalysisMode.percentChance) {
      pct = currentResult;
    }
    if (scs == null && currentMode == AnalysisMode.cohesionScore) {
      scs = currentResult;
    }

    final hasScenario = _hasScenarioInput(input);
    final working = grokConstrualEnabled
        ? WardGrokConstrual.applyHeuristic(input, locale)
        : input;
    if (pct == null && hasScenario) {
      pct = engine.analyze(
        working,
        mode: AnalysisMode.percentChance,
        locale: locale,
      );
    }
    if (scs == null && hasScenario) {
      scs = engine.analyze(
        working,
        mode: AnalysisMode.cohesionScore,
        locale: locale,
      );
    }

    if (pct != null && scs != null) {
      return buildDual(
        percentResult: pct,
        cohesionResult: scs,
        input: input,
        locale: locale,
        strings: strings,
        conclusionExcerptOverride: conclusionExcerptOverride,
        grokConstrualEnabled: grokConstrualEnabled,
      );
    }

    return build(
      result: currentResult,
      input: input,
      mode: currentMode,
      locale: locale,
      strings: strings,
      conclusionExcerptOverride: conclusionExcerptOverride,
      grokConstrualEnabled: grokConstrualEnabled,
    );
  }

  /// Upgrades a previously created single-mode conclusion link to dual % + SCS.
  static Future<WardConclusionLink> enrichLinkToDualAsync({
    required WardConclusionLink seed,
    required LocaleConfig locale,
    required AppLocalizations strings,
    bool grokConstrualEnabled = false,
    Future<ScenarioInput> Function(ScenarioInput)? construe,
    EvolveEngine engine = const EvolveEngine(),
  }) async {
    if (seed.dualAnalysis &&
        seed.percentChance != null &&
        seed.refinedScs != null &&
        (!grokConstrualEnabled || seed.grokEnriched)) {
      return seed;
    }

    final question = seed.posedQuestion.trim();
    if (question.isEmpty) return seed;

    var input = ScenarioInput(
      topic: seed.topic,
      posedQuestion: question,
    );
    final useGrok = grokConstrualEnabled || seed.grokEnriched;
    if (useGrok) {
      if (construe != null) {
        input = await construe(input);
      } else {
        input = WardGrokConstrual.applyHeuristic(input, locale);
      }
    }

    return _enrichInputToDual(
      seed: seed,
      input: input,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: useGrok,
      engine: engine,
    );
  }

  static WardConclusionLink enrichLinkToDual({
    required WardConclusionLink seed,
    required LocaleConfig locale,
    required AppLocalizations strings,
    bool grokConstrualEnabled = false,
    EvolveEngine engine = const EvolveEngine(),
  }) {
    if (seed.dualAnalysis &&
        seed.percentChance != null &&
        seed.refinedScs != null) {
      return seed;
    }

    final question = seed.posedQuestion.trim();
    if (question.isEmpty) return seed;

    var input = ScenarioInput(
      topic: seed.topic,
      posedQuestion: question,
    );
    if (grokConstrualEnabled || seed.grokEnriched) {
      input = WardGrokConstrual.applyHeuristic(input, locale);
    }

    return _enrichInputToDual(
      seed: seed,
      input: input,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: grokConstrualEnabled || seed.grokEnriched,
      engine: engine,
    );
  }

  static WardConclusionLink _enrichInputToDual({
    required WardConclusionLink seed,
    required ScenarioInput input,
    required LocaleConfig locale,
    required AppLocalizations strings,
    required bool grokConstrualEnabled,
    EvolveEngine engine = const EvolveEngine(),
  }) {
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
    final dual = buildDual(
      percentResult: percentResult,
      cohesionResult: cohesionResult,
      input: input,
      locale: locale,
      strings: strings,
      conclusionExcerptOverride: seed.conclusionExcerpt,
      grokConstrualEnabled: grokConstrualEnabled,
    );

    return WardConclusionLink(
      title: seed.title.isNotEmpty ? seed.title : dual.title,
      summary: dual.summary,
      wardName: seed.wardName.isNotEmpty ? seed.wardName : dual.wardName,
      voteCommentPrefill: dual.voteCommentPrefill,
      analysisMode: seed.analysisMode,
      outcomeScore: seed.outcomeScore,
      conclusionExcerpt: seed.conclusionExcerpt.isNotEmpty
          ? seed.conclusionExcerpt
          : dual.conclusionExcerpt,
      grokEnriched: seed.grokEnriched || dual.grokEnriched,
      posedQuestion: seed.posedQuestion,
      topic: seed.topic,
      dualAnalysis: true,
      percentChance: dual.percentChance,
      percentPhrase: dual.percentPhrase,
      refinedScs: dual.refinedScs,
      scsLean: dual.scsLean,
    );
  }

  /// Runs open dual analysis (no PERC faucet) and returns a combined link.
  static Future<WardConclusionLink> buildFromScenarioAsync({
    required ScenarioInput input,
    required LocaleConfig locale,
    required AppLocalizations strings,
    bool grokConstrualEnabled = false,
    Future<ScenarioInput> Function(ScenarioInput)? construe,
    EvolveEngine engine = const EvolveEngine(),
  }) async {
    var working = input;
    if (grokConstrualEnabled) {
      if (construe != null) {
        working = await construe(working);
      } else {
        working = WardGrokConstrual.applyHeuristic(working, locale);
      }
    }
    return buildFromScenario(
      input: working,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: grokConstrualEnabled,
      engine: engine,
    );
  }

  static WardConclusionLink buildFromScenario({
    required ScenarioInput input,
    required LocaleConfig locale,
    required AppLocalizations strings,
    bool grokConstrualEnabled = false,
    EvolveEngine engine = const EvolveEngine(),
  }) {
    var working = input;
    if (grokConstrualEnabled) {
      working = WardGrokConstrual.applyHeuristic(working, locale);
    }
    final percentResult = engine.analyze(
      working,
      mode: AnalysisMode.percentChance,
      locale: locale,
    );
    final cohesionResult = engine.analyze(
      working,
      mode: AnalysisMode.cohesionScore,
      locale: locale,
    );
    return buildDual(
      percentResult: percentResult,
      cohesionResult: cohesionResult,
      input: working,
      locale: locale,
      strings: strings,
      grokConstrualEnabled: grokConstrualEnabled,
    );
  }

  static String _proposalTitle(String question, String topic, String excerpt) {
    if (question.isNotEmpty) return question;
    if (topic.isNotEmpty) return topic;
    if (excerpt.isNotEmpty) return excerpt.split('\n').first.trim();
    return 'Evolve analysis conclusion';
  }

  static String _conclusionExcerpt(
    EvolveResult result,
    AnalysisMode mode,
    LocaleConfig locale,
  ) {
    if (mode == AnalysisMode.percentChance) {
      final split = ConclusionExplainer.splitGrokReply(result.grokStyleReply, locale);
      if (split.conclusion.isNotEmpty) return split.conclusion;
      return result.continuumConclusion;
    }
    final split = ConclusionExplainer.splitCohesionReport(result.cohesionReport, locale);
    if (split.conclusion.isNotEmpty) return split.conclusion;
    return result.partThreeConclusion.headline;
  }

  static String _dualConclusionExcerpt(
    EvolveResult percentResult,
    EvolveResult cohesionResult,
    LocaleConfig locale,
  ) {
    final pct = _conclusionExcerpt(percentResult, AnalysisMode.percentChance, locale);
    if (pct.isNotEmpty) return pct;
    return _conclusionExcerpt(cohesionResult, AnalysisMode.cohesionScore, locale);
  }

  static String _percentLine(EvolveResult result, String modeLabel) {
    final phrase = result.percentPhrase.trim();
    final core = '${result.percentChance.round()}%';
    return phrase.isEmpty ? '$modeLabel · $core' : '$modeLabel · $core · $phrase';
  }

  static String _scsLine(
    EvolveResult result,
    LocalizedOutput output,
    String modeLabel,
  ) {
    final lean = output.leanLabel(result.core.lean);
    return '$modeLabel · ${result.core.refinedScs.round()}/100 SCS · $lean';
  }

  static String _grokSnippet(String reply, LocaleConfig locale) {
    final split = ConclusionExplainer.splitGrokReply(reply, locale);
    final body = split.body.trim();
    if (body.isEmpty) return '';
    return _truncate(body, _maxGrokSnippetLen);
  }

  static String _buildSummary({
    required String excerpt,
    required String modeLabel,
    required String outcomeLabel,
    required String lean,
    required String grokSnippet,
    required bool grokEnriched,
    required AppLocalizations strings,
  }) {
    final buf = StringBuffer()
      ..writeln(strings.t('ward_conclusion_link_summary_header'))
      ..writeln('$modeLabel · $outcomeLabel · $lean')
      ..writeln();
    if (excerpt.isNotEmpty) {
      buf.writeln(excerpt);
      buf.writeln();
    }
    if (grokEnriched && grokSnippet.isNotEmpty) {
      buf.writeln(strings.t('ward_conclusion_link_grok_note'));
      buf.writeln(grokSnippet);
    }
    return buf.toString().trim();
  }

  static String _buildDualSummary({
    required String percentLine,
    required String scsLine,
    required String excerpt,
    required String grokSnippet,
    required bool grokEnriched,
    required AppLocalizations strings,
  }) {
    final buf = StringBuffer()
      ..writeln(strings.t('ward_dual_summary_header'))
      ..writeln(percentLine)
      ..writeln(scsLine)
      ..writeln();
    if (excerpt.isNotEmpty) {
      buf.writeln(excerpt);
      buf.writeln();
    }
    if (grokEnriched && grokSnippet.isNotEmpty) {
      buf.writeln(strings.t('ward_conclusion_link_grok_note'));
      buf.writeln(grokSnippet);
    }
    return buf.toString().trim();
  }

  static String _buildVoteComment({
    required String question,
    required String modeLabel,
    required String outcomeLabel,
    required String lean,
    required String excerpt,
    required String grokSnippet,
    required AppLocalizations strings,
  }) {
    final buf = StringBuffer()
      ..writeln(strings.t('ward_conclusion_link_vote_prefill_header'));
    if (question.isNotEmpty) {
      buf.writeln('${strings.t('ward_conclusion_link_question')}: $question');
    }
    buf.writeln('$modeLabel · $outcomeLabel · $lean');
    if (excerpt.isNotEmpty) {
      buf.writeln();
      buf.writeln(excerpt);
    }
    if (grokSnippet.isNotEmpty) {
      buf.writeln();
      buf.writeln(strings.t('ward_conclusion_link_grok_note'));
      buf.writeln(grokSnippet);
    }
    return buf.toString().trim();
  }

  static String _buildDualVoteComment({
    required String question,
    required String percentLine,
    required String scsLine,
    required String excerpt,
    required String grokSnippet,
    required AppLocalizations strings,
  }) {
    final buf = StringBuffer()
      ..writeln(strings.t('ward_dual_vote_prefill_header'));
    if (question.isNotEmpty) {
      buf.writeln('${strings.t('ward_conclusion_link_question')}: $question');
    }
    buf.writeln(percentLine);
    buf.writeln(scsLine);
    if (excerpt.isNotEmpty) {
      buf.writeln();
      buf.writeln(excerpt);
    }
    if (grokSnippet.isNotEmpty) {
      buf.writeln();
      buf.writeln(strings.t('ward_conclusion_link_grok_note'));
      buf.writeln(grokSnippet);
    }
    return buf.toString().trim();
  }

  static bool _hasScenarioInput(ScenarioInput input) =>
      input.posedQuestion.trim().isNotEmpty ||
      input.topic.trim().isNotEmpty ||
      input.scenarioQuery.trim().isNotEmpty;

  static String _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = v?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static String _truncate(String text, int maxLen) {
    final t = text.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen - 1).trim()}…';
  }
}