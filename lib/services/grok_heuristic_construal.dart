import '../l10n/localized_output.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'construal_grounding.dart';
import 'grok_field_sanitizer.dart';
import 'question_parameter_scraper.dart';
import 'question_semantics.dart';

/// Discourse-style construct suggestions when no live Grok proxy is reachable.
class GrokHeuristicConstrual {
  const GrokHeuristicConstrual._();

  static GrokConstrualResult suggest({
    required ScenarioInput input,
    required LocaleConfig locale,
    LocalizedOutput? output,
  }) {
    final out = output ?? LocalizedOutput.of(locale);
    final question = input.scenarioQuery.trim();
    if (question.isEmpty) return const GrokConstrualResult(provenance: 'grok-heuristic-web');

    final region = out.regionName(locale.regionId);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: region,
    );
    final scraped = QuestionParameterScraper.scrape(
      question: question,
      topic: input.topic,
      sem: sem,
    );
    final pathway = input.activePathwayLabel.trim();

    String pick(String existing, String construct) {
      if (existing.trim().isNotEmpty) return existing.trim();
      final base = scraped[construct]?.trim() ?? '';
      if (base.isEmpty) return base;
      if (pathway.isEmpty || construct == 'continuum') return base;
      return _pathwayBiasLine(base, pathway, construct);
    }

    final result = GrokConstrualResult(
      continuumText: pick(input.continuumText, 'continuum'),
      vortexText: pick(input.vortexText, 'vortex'),
      shearText: pick(input.shearText, 'shear'),
      resistanceText: pick(input.resistanceText, 'resistance'),
      flowText: pick(input.flowText, 'flow'),
      provenance: 'grok-heuristic-web',
    );
    final sanitized = GrokFieldSanitizer.sanitizeResult(
      raw: result,
      input: input,
      locale: locale,
      output: out,
    );
    return ConstrualGrounding.ensureResult(
      result: sanitized,
      input: input,
      locale: locale,
      output: out,
    );
  }

  static String _pathwayBiasLine(String base, String pathway, String construct) {
    final lower = pathway.toLowerCase();
    final bias = switch (construct) {
      'vortex' => _vortexPathwayBias(lower),
      'shear' => _shearPathwayBias(lower),
      'resistance' => _resistancePathwayBias(lower),
      'flow' => _flowPathwayBias(lower),
      _ => '',
    };
    if (bias.isEmpty) {
      return '$base — $pathway-specific lever emphasis.';
    }
    return '$base — $pathway: $bias';
  }

  static String _vortexPathwayBias(String lower) {
    if (RegExp(r'austerity|fiscal tightening|cuts|tighten').hasMatch(lower)) {
      return 'Treasury and central-bank briefings favour consolidation framing.';
    }
    if (RegExp(r'stimulus|spending|investment|inject').hasMatch(lower)) {
      return 'Cabinet and spending ministries signal intervention-led circulation.';
    }
    if (RegExp(r'status quo|remain|baseline|unchanged').hasMatch(lower)) {
      return 'Incumbent institutions reinforce continuity briefings.';
    }
    return 'Authority lanes tilt toward this route over sibling pathways.';
  }

  static String _shearPathwayBias(String lower) {
    if (RegExp(r'austerity|cuts|tighten').hasMatch(lower)) {
      return 'street discourse sharpens grievance over service cuts and wage squeeze.';
    }
    if (RegExp(r'stimulus|spending|investment').hasMatch(lower)) {
      return 'pro-spending forums amplify partisan split against fiscal hawks.';
    }
    if (RegExp(r'leave|exit|breakaway|secession').hasMatch(lower)) {
      return 'identity-layer grievance and rally rhetoric intensify shear.';
    }
    return 'open-channel polarisation clusters around this pathway label.';
  }

  static String _resistancePathwayBias(String lower) {
    if (RegExp(r'austerity|fiscal tightening').hasMatch(lower)) {
      return 'parliamentary and regulatory guardrails slow deep retrenchment.';
    }
    if (RegExp(r'stimulus|spending').hasMatch(lower)) {
      return 'fiscal sceptics and bond-market drag dampen rapid stimulus scale-up.';
    }
    return 'procedural and compliance friction absorbs pressure on this route.';
  }

  static String _flowPathwayBias(String lower) {
    if (RegExp(r'austerity|cuts').hasMatch(lower)) {
      return 'austerity narrative compresses into headline certainty on broadcast reach.';
    }
    if (RegExp(r'stimulus|spending').hasMatch(lower)) {
      return 'investment story travels unevenly across expert vs activist channels.';
    }
    return 'trust transport diverges from sibling pathways on this label.';
  }
}