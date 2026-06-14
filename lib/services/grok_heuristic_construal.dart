import '../l10n/localized_output.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'grok_construct_discourse.dart';
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
    final question = input.posedQuestion.trim();
    if (question.isEmpty) return const GrokConstrualResult(provenance: 'grok-heuristic-web');

    final region = out.regionName(locale.regionId);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: region,
    );

    String pick(String existing, String construct) {
      if (existing.trim().isNotEmpty) return existing.trim();
      return GrokConstructDiscourse.forConstruct(
        construct: construct,
        subject: sem.displaySubject,
        region: region,
        hintSignals: sem.hintSignals,
      );
    }

    return GrokConstrualResult(
      vortexText: pick(input.vortexText, 'vortex'),
      shearText: pick(input.shearText, 'shear'),
      resistanceText: pick(input.resistanceText, 'resistance'),
      flowText: pick(input.flowText, 'flow'),
      provenance: 'grok-heuristic-web',
    );
  }
}