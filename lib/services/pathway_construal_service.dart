import '../models/grok_session.dart';
import '../models/pathway_construct_texts.dart';
import '../models/scenario_input.dart';
import 'multi_part_question_parser.dart';

/// Per-pathway Grok construal — one discourse scrape per shared-outcome pathway.
class PathwayConstrualService {
  const PathwayConstrualService._();

  static bool shouldFetchPerPathway(ScenarioInput input) =>
      input.multiPartOutcomeEnabled && input.filledOutcomeParts.length >= 2;

  static String normalizeKey(String label) => label.trim().toLowerCase();

  /// Builds sub-questions for each filled pathway (explicit fields only).
  static MultiPartQuestion? resolvePathways(ScenarioInput input) =>
      MultiPartQuestionParser.fromExplicitFields(input);

  /// Merges per-pathway ω/σ/Iτ/Jμ into labelled composite construct fields.
  static ScenarioInput applyPerPathwayResults({
    required ScenarioInput source,
    required Map<String, PathwayConstructTexts> pathwayConstruals,
    required List<String> labelsInOrder,
  }) {
    return source.copyWith(
      pathwayConstruals: pathwayConstruals,
      vortexText: _mergeField(source.vortexText, pathwayConstruals, labelsInOrder, 'vortex'),
      shearText: _mergeField(source.shearText, pathwayConstruals, labelsInOrder, 'shear'),
      resistanceText:
          _mergeField(source.resistanceText, pathwayConstruals, labelsInOrder, 'resistance'),
      flowText: _mergeField(source.flowText, pathwayConstruals, labelsInOrder, 'flow'),
    );
  }

  static String _mergeField(
    String existing,
    Map<String, PathwayConstructTexts> map,
    List<String> labels,
    String constructKey,
  ) {
    if (existing.trim().isNotEmpty) return existing.trim();

    final lines = <String>[];
    for (final label in labels) {
      final texts = map[normalizeKey(label)];
      if (texts == null || texts.isEmpty) continue;
      final line = texts.textFor(constructKey).trim();
      if (line.isEmpty) continue;
      lines.add('• $label: $line');
    }
    return lines.join('\n');
  }

  static Map<String, PathwayConstructTexts> mapFromResults(
    List<String> labels,
    List<GrokConstrualResult> results,
  ) {
    final map = <String, PathwayConstructTexts>{};
    for (var i = 0; i < labels.length && i < results.length; i++) {
      map[normalizeKey(labels[i])] = PathwayConstructTexts.fromGrok(results[i]);
    }
    return map;
  }
}