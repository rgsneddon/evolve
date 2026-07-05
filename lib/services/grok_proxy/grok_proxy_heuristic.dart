import '../../models/grok_session.dart';
import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../grok_heuristic_construal.dart';
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
        'continuumText': result.continuumText,
        'vortexText': result.vortexText,
        'shearText': result.shearText,
        'resistanceText': result.resistanceText,
        'flowText': result.flowText,
        'provenance': mock ? 'grok-mock' : result.provenance,
      };
    }

    final siblings = (payload['siblingPathwayLabels'] as List<dynamic>? ?? const [])
        .map((s) => '$s'.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final input = ScenarioInput(
      posedQuestion: question,
      topic: '${payload['topic'] ?? ''}',
      activePathwayLabel: '${payload['pathwayLabel'] ?? ''}',
      siblingPathwayLabels: siblings,
      parentPosedQuestion: '${payload['parentPosedQuestion'] ?? ''}',
      vortexText: '${payload['vortexText'] ?? ''}',
      shearText: '${payload['shearText'] ?? ''}',
      resistanceText: '${payload['resistanceText'] ?? ''}',
      flowText: '${payload['flowText'] ?? ''}',
    );
    final locale = LocaleConfig(regionId: regionId, languageCode: 'en');

    final result = GrokHeuristicConstrual.suggest(
      input: input,
      locale: locale,
    );

    return {
      'continuumText': result.continuumText,
      'vortexText': result.vortexText,
      'shearText': result.shearText,
      'resistanceText': result.resistanceText,
      'flowText': result.flowText,
      'provenance': mock ? 'grok-mock' : result.provenance,
    };
  }

  static Map<String, dynamic> _empty({required bool mock}) => {
        'continuumText': '',
        'vortexText': '',
        'shearText': '',
        'resistanceText': '',
        'flowText': '',
        'provenance': mock ? 'grok-mock' : 'grok-heuristic-proxy',
      };
}