import '../l10n/localized_output.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'question_parameter_scraper.dart';
import 'question_relevance_filter.dart';
import 'question_semantics.dart';

/// Ensures ω/σ/Iτ/Jμ construal fields stay fully tied to the posed question.
class ConstrualGrounding {
  const ConstrualGrounding._();

  static GrokConstrualResult ensureResult({
    required GrokConstrualResult result,
    required ScenarioInput input,
    required LocaleConfig locale,
    LocalizedOutput? output,
    String? relevanceQuestion,
  }) {
    final out = output ?? LocalizedOutput.of(locale);
    final question = (relevanceQuestion ?? input.scenarioQuery).trim();
    if (question.isEmpty) return result;

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

    String userField(String construct) => switch (construct) {
          'continuum' => input.continuumText,
          'vortex' => input.vortexText,
          'shear' => input.shearText,
          'resistance' => input.resistanceText,
          'flow' => input.flowText,
          _ => '',
        };

    String ground(String field, String construct) {
      final user = userField(construct).trim();
      if (user.isNotEmpty) return user;

      final trimmed = field.trim();
      if (trimmed.isEmpty) return scraped[construct]?.trim() ?? '';
      if (QuestionRelevanceFilter.isFullyQuestionGrounded(
        trimmed,
        posedQuestion: question,
        displaySubject: sem.displaySubject,
        rawSubject: sem.subject,
        topic: input.topic,
      )) {
        return trimmed;
      }
      return scraped[construct]?.trim() ?? trimmed;
    }

    return GrokConstrualResult(
      continuumText: ground(result.continuumText, 'continuum'),
      vortexText: ground(result.vortexText, 'vortex'),
      shearText: ground(result.shearText, 'shear'),
      resistanceText: ground(result.resistanceText, 'resistance'),
      flowText: ground(result.flowText, 'flow'),
      provenance: result.provenance,
    );
  }
}