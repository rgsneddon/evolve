import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'pathway_construal_service.dart';
import '../models/evolve_result.dart';
import 'chronoflux_weight_construal.dart';
import 'question_parameter_scraper.dart';
import 'question_semantics.dart';
import 'scenario_calculation_context.dart';
import 'social_discourse_construal.dart';

/// Blends parent construal with pathway-specific discourse for partition weights.
class PartPathwayWeightConstrual {
  const PartPathwayWeightConstrual._();

  /// Merges parent ω/σ/Iτ/Jμ construal with pathway-anchored scrape lines.
  static ScenarioInput pathwayInput({
    required ScenarioInput parent,
    required String pathwayLabel,
    required String subQuestion,
    required LocaleConfig locale,
    required LocalizedOutput output,
  }) {
    final scoped = parent.copyWith(posedQuestion: subQuestion);
    final dedicated =
        parent.pathwayConstruals[PathwayConstrualService.normalizeKey(pathwayLabel)];
    if (dedicated != null && dedicated.isNotEmpty) {
      return scoped.copyWith(
        vortexText: dedicated.vortexText,
        shearText: dedicated.shearText,
        resistanceText: dedicated.resistanceText,
        flowText: dedicated.flowText,
      );
    }

    final sem = QuestionSemantics.parse(
      scoped,
      regionId: locale.regionId,
      regionLabel: output.regionName(locale.regionId),
    );
    final scraped = QuestionParameterScraper.scrape(
      question: subQuestion,
      topic: parent.topic,
      sem: sem,
    );

    return scoped.copyWith(
      vortexText: _blendField(parent.vortexText, scraped['vortex'] ?? '', pathwayLabel),
      shearText: _blendField(parent.shearText, scraped['shear'] ?? '', pathwayLabel),
      resistanceText:
          _blendField(parent.resistanceText, scraped['resistance'] ?? '', pathwayLabel),
      flowText: _blendField(parent.flowText, scraped['flow'] ?? '', pathwayLabel),
    );
  }

  /// Reflective partition weight — calibrated forecast + discourse + construal data.
  static double reflectivePartitionWeight({
    required ScenarioInput pathwayInput,
    required String pathwayLabel,
    required double calibratedPercent,
    required HydrodynamicCore core,
    required LocaleConfig locale,
    required LocalizedOutput output,
  }) {
    final sem = QuestionSemantics.parse(
      pathwayInput,
      regionId: locale.regionId,
      regionLabel: output.regionName(locale.regionId),
    );
    final theme = const SocialDiscourseConstrual().detect(pathwayInput, sem);
    final calcCtx = ScenarioCalculationContext.from(
      input: pathwayInput,
      regionId: locale.regionId,
      lean: core.lean,
    );
    final weights = const ChronofluxWeightConstrual().construeFromContext(calcCtx);
    final salient = QuestionParameterScraper.salientPhrases(
      question: pathwayInput.posedQuestion,
      topic: pathwayInput.topic,
      subject: sem.subject,
    );

    final discourse = _discourseSalience(
      theme: theme,
      pathwayLabel: pathwayLabel,
      input: pathwayInput,
      sem: sem,
      salient: salient,
    );
    final construal = _construalDataSalience(
      input: pathwayInput,
      core: core,
      normalizedWeights: weights.normalized,
    );
    final pathwaySignal = _pathwayDiscourseSignal(
      pathwayLabel: pathwayLabel,
      theme: theme,
      core: core,
    );

    final constructSpread = _pathwayConstructSpread(
      pathwayInput: pathwayInput,
      pathwayLabel: pathwayLabel,
    );

    return (
      calibratedPercent * 0.48 +
      discourse * 0.24 +
      construal * 0.16 +
      pathwaySignal * 0.12 +
      constructSpread * 0.10
    ).clamp(1.0, 100.0);
  }

  /// Pathway-specific construct fingerprint — rewards divergent ω/σ/Iτ/Jμ profiles.
  static double _pathwayConstructSpread({
    required ScenarioInput pathwayInput,
    required String pathwayLabel,
  }) {
    final scs = [
      pathwayInput.vortex.scs,
      pathwayInput.shear.scs,
      pathwayInput.flow.scs,
      pathwayInput.resistance.scs,
      pathwayInput.continuum.scs,
    ];
    final mean = scs.fold(0.0, (a, b) => a + b) / scs.length;
    final variance =
        scs.map((s) => (s - mean) * (s - mean)).fold(0.0, (a, b) => a + b) /
            scs.length;

    var spread = 34.0 + variance * 0.55 + (mean - 50).abs() * 0.35;

    final label = pathwayLabel.trim().toLowerCase();
    if (label.isNotEmpty) {
      spread += (label.codeUnits.fold<int>(0, (a, c) => a + c) % 21);
    }

    final combined = [
      pathwayInput.vortexText,
      pathwayInput.shearText,
      pathwayInput.resistanceText,
      pathwayInput.flowText,
    ].where((t) => t.trim().isNotEmpty).join(' ').toLowerCase();
    if (label.isNotEmpty && combined.contains(label)) {
      spread += 14;
    }

    return spread.clamp(16.0, 84.0);
  }

  static String _blendField(String parent, String scraped, String pathwayLabel) {
    final p = parent.trim();
    final s = scraped.trim();
    final label = pathwayLabel.trim();
    if (p.isEmpty) return s;
    if (s.isEmpty) return p;
    if (p.toLowerCase().contains(label.toLowerCase())) return p;
    final snippet = _pathwaySnippet(s, label);
    return snippet.isEmpty ? p : '$p — $snippet';
  }

  static String _pathwaySnippet(String scraped, String label) {
    final lower = scraped.toLowerCase();
    final idx = lower.indexOf(label.toLowerCase());
    if (idx >= 0) {
      final prior = scraped.lastIndexOf(RegExp(r'[.;]\s+'), idx);
      final start = prior < 0 ? 0 : prior + 1;
      return scraped.substring(start).trim();
    }
    return '$label: ${scraped.length > 96 ? '${scraped.substring(0, 95)}…' : scraped}';
  }

  static double _discourseSalience({
    required DiscourseTheme theme,
    required String pathwayLabel,
    required ScenarioInput input,
    required QuestionSemantics sem,
    required List<String> salient,
  }) {
    final shear = input.shear.scs;
    final flow = input.flow.scs;
    final resistance = input.resistance.scs;

    var score = shear * 0.42 + flow * 0.28 + (100 - resistance) * 0.12;
    score += _pathwayThemeAlignment(pathwayLabel, theme);
    score += _tokenOverlapBoost(pathwayLabel, salient);
    score += sem.hintSignals.length * 1.5;

    return score.clamp(12.0, 88.0);
  }

  static double _pathwayThemeAlignment(String label, DiscourseTheme theme) {
    final l = label.toLowerCase();
    final match = switch (theme) {
      DiscourseTheme.economic =>
        RegExp(r'austerity|stimulus|fiscal|recession|inflation|budget|tax|spending|landing'),
      DiscourseTheme.protest =>
        RegExp(r'unrest|strike|march|riot|disorder|protest|rally'),
      DiscourseTheme.electoral =>
        RegExp(r'election|vote|campaign|ballot|remain|leave|coalition'),
      DiscourseTheme.trust =>
        RegExp(r'trust|credibility|narrative|confidence|reputation'),
      DiscourseTheme.accountability =>
        RegExp(r'resign|scandal|inquiry|accountability|misconduct'),
      DiscourseTheme.official =>
        RegExp(r'policy|minister|government|cabinet|mandate|status quo'),
      DiscourseTheme.open => RegExp(r'.'),
    };
    return match.hasMatch(l) ? 14.0 : 4.0;
  }

  static double _tokenOverlapBoost(String label, List<String> tokens) {
    final words = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();
    if (words.isEmpty || tokens.isEmpty) return 0;
    final overlap =
        tokens.where((t) => words.any((w) => t.toLowerCase().contains(w))).length;
    return (overlap * 3.5).clamp(0, 12);
  }

  static double _pathwayDiscourseSignal({
    required String pathwayLabel,
    required DiscourseTheme theme,
    required HydrodynamicCore core,
  }) {
    final l = pathwayLabel.toLowerCase();
    var signal = 48.0;

    if (RegExp(r'austerity|fiscal tightening|hard landing|cuts|tighten').hasMatch(l)) {
      signal += core.regressivePct * 0.22;
      if (theme == DiscourseTheme.economic) signal += 10;
    } else if (RegExp(r'stimulus|spending|soft landing|investment|inject').hasMatch(l)) {
      signal += core.progressivePct * 0.22;
      if (theme == DiscourseTheme.economic) signal += 8;
    } else if (RegExp(r'status quo|remain|baseline|unchanged').hasMatch(l)) {
      signal += (100 - core.refinedScs) * 0.14;
    } else if (RegExp(r'leave|exit|breakaway|secession').hasMatch(l)) {
      signal += core.regressivePct * 0.16 + core.shearScs * 0.08;
    } else {
      signal += core.regressivePct * 0.08 + core.progressivePct * 0.06;
    }

    signal += (l.codeUnits.fold<int>(0, (a, c) => a + c) % 19);
    return signal.clamp(14.0, 86.0);
  }

  static double _construalDataSalience({
    required ScenarioInput input,
    required HydrodynamicCore core,
    required List<double> normalizedWeights,
  }) {
    final scs = [
      input.vortex.scs,
      input.flow.scs,
      input.shear.scs,
      input.resistance.scs,
      input.continuum.scs,
    ];
    var weighted = 0.0;
    for (var i = 0; i < scs.length && i < normalizedWeights.length; i++) {
      weighted += scs[i] * normalizedWeights[i];
    }

    final strain = (100 - core.refinedScs).clamp(0, 100);
    final momentum = core.regressivePct.clamp(0, 100);

    return (weighted * 0.55 + strain * 0.25 + momentum * 0.20).clamp(12.0, 88.0);
  }
}