import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../grok_construct_discourse.dart';
import '../narrative_construct_construal.dart';

/// Lightweight heuristic construal for the standalone Grok proxy (no Flutter deps).
class GrokProxyHeuristic {
  const GrokProxyHeuristic._();

  static Map<String, dynamic> suggest(
    Map<String, dynamic> payload, {
    bool mock = false,
  }) {
    final question = '${payload['posedQuestion'] ?? ''}'.trim();
    final narrative = '${payload['narrativeText'] ?? ''}'.trim();
    final sourceUrl = '${payload['sourceUrl'] ?? ''}'.trim();
    final region = '${payload['regionLabel'] ?? payload['regionId'] ?? 'global'}';
    final regionId = '${payload['regionId'] ?? 'global'}';

    if (question.isEmpty && narrative.isEmpty) {
      return _empty(mock: mock);
    }

    if (sourceUrl.isNotEmpty && narrative.isNotEmpty) {
      final input = ScenarioInput(
        posedQuestion: narrative,
        topic: '${payload['topic'] ?? ''}',
        sourceUrl: sourceUrl,
        vortexText: '${payload['vortexText'] ?? ''}',
        shearText: '${payload['shearText'] ?? ''}',
        resistanceText: '${payload['resistanceText'] ?? ''}',
        flowText: '${payload['flowText'] ?? ''}',
      );
      final result = NarrativeConstructConstrual.suggest(
        input: input,
        locale: LocaleConfig(regionId: regionId, languageCode: 'en'),
      );
      return {
        'vortexText': result.vortexText,
        'shearText': result.shearText,
        'resistanceText': result.resistanceText,
        'flowText': result.flowText,
        'provenance': mock ? 'grok-mock' : result.provenance,
      };
    }

    String pick(String existing, String construct) {
      if (existing.trim().isNotEmpty) return existing.trim();
      return GrokConstructDiscourse.fromQuestion(
        construct: construct,
        posedQuestion: question,
        regionId: regionId,
        regionLabel: region,
      );
    }

    return {
      'vortexText': pick('${payload['vortexText'] ?? ''}', 'vortex'),
      'shearText': pick('${payload['shearText'] ?? ''}', 'shear'),
      'resistanceText': pick('${payload['resistanceText'] ?? ''}', 'resistance'),
      'flowText': pick('${payload['flowText'] ?? ''}', 'flow'),
      'provenance': mock ? 'grok-mock' : 'grok-heuristic-proxy',
    };
  }

  static Map<String, dynamic> _empty({required bool mock}) => {
        'vortexText': '',
        'shearText': '',
        'resistanceText': '',
        'flowText': '',
        'provenance': mock ? 'grok-mock' : 'grok-heuristic-proxy',
      };
}