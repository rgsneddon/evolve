import '../l10n/app_localizations.dart';
import '../models/locale_config.dart';

/// Detects the main decision-maker in a scenario for PART THREE actions.
class ScenarioAgentDetector {
  const ScenarioAgentDetector();

  static const _patterns = <String, String>{
    r'\bmayor\b': 'mayor',
    r'\bgovernor\b': 'governor',
    r'\bminister\b': 'minister',
    r'\bpresident\b': 'president',
    r'\bprime minister\b': 'prime_minister',
    r'\bfirst minister\b': 'first_minister',
    r'\bchief executive\b': 'chief_executive',
    r'\bceo\b': 'chief_executive',
    r'\bdirector[- ]general\b': 'director_general',
    r'\bcommissioner\b': 'commissioner',
    r'\bprefect\b': 'prefect',
    r'\bgovernor[- ]general\b': 'governor_general',
    r'\b(city|municipal|local) council\b': 'council',
    r'\bparliament\b': 'parliament',
    r'\bsenate\b': 'senate',
    r'\bassembly\b': 'assembly',
    r'\bauthority\b': 'authority',
    r'\bagency\b': 'agency',
  };

  String detect({
    required String scenarioText,
    required String topic,
    required LocaleConfig locale,
    required AppLocalizations strings,
  }) {
    final haystack = '${topic.toLowerCase()} ${scenarioText.toLowerCase()}';

    for (final entry in _patterns.entries) {
      if (RegExp(entry.key).hasMatch(haystack)) {
        return strings.agentRole(entry.value, locale.regionId);
      }
    }

    return strings.agentRole('lead_authority', locale.regionId);
  }
}