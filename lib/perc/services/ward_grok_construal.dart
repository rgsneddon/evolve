import '../../l10n/localized_output.dart';
import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../../services/grok_construal_service.dart';
import '../../services/grok_heuristic_construal.dart';
import '../../services/narrative_construct_construal.dart';

/// Grok construal for ward voting open analysis (no home-form mutation).
class WardGrokConstrual {
  const WardGrokConstrual._();

  static ScenarioInput applyHeuristic(
    ScenarioInput input,
    LocaleConfig locale,
  ) {
    final output = LocalizedOutput.of(locale);
    final suggestions = NarrativeConstructConstrual.isNarrativeLinked(input)
        ? NarrativeConstructConstrual.suggest(
            input: input,
            locale: locale,
            output: output,
          )
        : GrokHeuristicConstrual.suggest(
            input: input,
            locale: locale,
            output: output,
          );
    return const GrokConstrualService().applySuggestions(input, suggestions);
  }
}