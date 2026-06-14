import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/party_response_scs.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'party_response_extractor.dart';
import 'question_semantics.dart';
import 'social_discourse_construal.dart';

/// Builds narrative SCS refinement from per-party response scores.
class PartyResponseAnalyzer {
  const PartyResponseAnalyzer({
    this.extractor = const PartyResponseExtractor(),
    this.discourse = const SocialDiscourseConstrual(),
  });

  final PartyResponseExtractor extractor;
  final SocialDiscourseConstrual discourse;

  NarrativePartyRefinement? buildRefinement({
    required ScenarioInput input,
    required List<PartyResponseScore> responses,
    required HydrodynamicCore core,
    required LocaleConfig locale,
    LocalizedOutput? output,
  }) {
    if (responses.isEmpty) return null;
    if (!extractor.narrativeReliesOnPartyResponses(input.scenarioQuery)) return null;

    final out = output ?? LocalizedOutput.of(locale);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );
    final theme = discourse.detect(input, sem);

    final partyAvg = _weightedPartyAverage(responses);
    var reliance = (0.1 + responses.length * 0.08).clamp(0.18, 0.48);
    if (theme == DiscourseTheme.official || theme == DiscourseTheme.trust) {
      reliance = (reliance + 0.08).clamp(0.18, 0.52);
    }

    final before = core.refinedScs;
    final refined =
        (before * (1 - reliance) + partyAvg * reliance).clamp(20.0, 87.0);

    return NarrativePartyRefinement(
      responses: responses,
      narrativeScsBefore: before,
      refinedNarrativeScs: refined,
      relianceWeight: reliance,
      summary: out.partyRefinementSummary(
        count: responses.length,
        before: before.round(),
        after: refined.round(),
        weightPct: (reliance * 100).round(),
      ),
    );
  }

  double _weightedPartyAverage(List<PartyResponseScore> scores) {
    if (scores.isEmpty) return 0;
    var weighted = 0.0;
    var total = 0.0;
    for (final s in scores) {
      final w = s.excerpt.length.clamp(12, 220).toDouble();
      weighted += s.scs * w;
      total += w;
    }
    return total > 0 ? weighted / total : scores.first.scs;
  }
}