import 'construct_input.dart';
import 'pathway_construct_texts.dart';

const int kFieldMaxLength = 5000;
const String kPartTwoCommand = 'RUN PART TWO';
const String kPartThreeCommand = 'RUN PART THREE';

class ScenarioInput {
  const ScenarioInput({
    this.topic = '',
    this.sourceUrl = '',
    this.posedQuestion = '',
    this.outcomeContext = '',
    this.outcomeParts = const [],
    this.multiPartOutcomeEnabled = false,
    this.activePathwayLabel = '',
    this.siblingPathwayLabels = const [],
    this.parentPosedQuestion = '',
    this.pathwayConstruals = const {},
    this.continuumText = '',
    this.vortexText = '',
    this.shearText = '',
    this.resistanceText = '',
    this.flowText = '',
    this.continuum = const ConstructInput(),
    this.flow = const ConstructInput(),
    this.shear = const ConstructInput(),
    this.resistance = const ConstructInput(),
    this.vortex = const ConstructInput(),
    this.applyLevers = true,
  });

  final String topic;
  final String sourceUrl;
  /// Base scenario query — anchors semantics, outputs, and ω inference.
  final String posedQuestion;
  /// Shared outcome clause for multi-part breakdown (e.g. "to end the recession").
  final String outcomeContext;
  /// User-entered pathway labels — one percent chance per non-empty part.
  final List<String> outcomeParts;
  /// When true, pathway fields and multi-part parsing produce a listed breakdown.
  final bool multiPartOutcomeEnabled;
  /// Active pathway label during per-pathway Grok construal (transient).
  final String activePathwayLabel;
  /// Sibling pathway labels for contrast during per-pathway Grok construal.
  final List<String> siblingPathwayLabels;
  /// Parent posed question before per-pathway sub-question substitution.
  final String parentPosedQuestion;
  /// Per-pathway ω/σ/Iτ/Jμ from individual Grok construal runs.
  final Map<String, PathwayConstructTexts> pathwayConstruals;
  /// Grok-construed ρt continuum observation (internal — not a manual UI field).
  final String continuumText;
  final String vortexText;
  final String shearText;
  final String resistanceText;
  final String flowText;
  final ConstructInput continuum;
  final ConstructInput flow;
  final ConstructInput shear;
  final ConstructInput resistance;
  final ConstructInput vortex;
  final bool applyLevers;

  List<ConstructInput> get constructs =>
      [continuum, flow, shear, resistance, vortex];

  static const constructKeys = ['vortex', 'shear', 'resistance', 'flow'];

  /// True when the user has posed the base scenario question.
  bool get hasQuestion =>
      posedQuestion.trim().isNotEmpty ||
      (multiPartOutcomeEnabled && filledOutcomeParts.length >= 2);

  /// Non-empty pathway labels entered under the posed question.
  List<String> get filledOutcomeParts =>
      outcomeParts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  bool get hasMultiPartOutcomeFields =>
      multiPartOutcomeEnabled && filledOutcomeParts.length >= 2;

  /// Enough scenario material for cohesion analysis (posed question is optional).
  bool get hasCohesionScenario =>
      sourceUrl.trim().isNotEmpty ||
      topic.trim().isNotEmpty ||
      posedQuestion.trim().isNotEmpty ||
      vortexText.trim().isNotEmpty ||
      shearText.trim().isNotEmpty ||
      resistanceText.trim().isNotEmpty ||
      flowText.trim().isNotEmpty;

  bool get hasAllConstructTexts =>
      vortexText.trim().isNotEmpty &&
      shearText.trim().isNotEmpty &&
      resistanceText.trim().isNotEmpty &&
      flowText.trim().isNotEmpty;

  List<String> get missingConstructKeys {
    final missing = <String>[];
    if (vortexText.trim().isEmpty) missing.add('vortex');
    if (shearText.trim().isEmpty) missing.add('shear');
    if (resistanceText.trim().isEmpty) missing.add('resistance');
    if (flowText.trim().isEmpty) missing.add('flow');
    return missing;
  }

  String constructText(String key) => switch (key) {
        'vortex' => vortexText,
        'shear' => shearText,
        'resistance' => resistanceText,
        'flow' => flowText,
        _ => '',
      };

  /// Primary query text — posed question, multi-part fields, or legacy vortex.
  String get scenarioQuery {
    final posed = posedQuestion.trim();
    if (posed.isNotEmpty) return posed;
    if (hasMultiPartOutcomeFields) {
      // Deferred import avoided — inline synthetic framing for display/engine.
      final list = filledOutcomeParts.join(', ');
      final toward = outcomeContext.trim().isNotEmpty ? ' ${outcomeContext.trim()}' : '';
      return 'Give the percent chances of each $list$toward?';
    }
    return vortexText.trim();
  }

  String? get posedQuestionLine => _extractQuestionLine(scenarioQuery);

  /// Legacy alias — conclusions reference the posed question.
  String? get vortexQuestion => posedQuestionLine;

  ScenarioInput copyWith({
    String? topic,
    String? sourceUrl,
    String? posedQuestion,
    String? outcomeContext,
    List<String>? outcomeParts,
    bool? multiPartOutcomeEnabled,
    String? activePathwayLabel,
    List<String>? siblingPathwayLabels,
    String? parentPosedQuestion,
    Map<String, PathwayConstructTexts>? pathwayConstruals,
    String? continuumText,
    String? vortexText,
    String? shearText,
    String? resistanceText,
    String? flowText,
    ConstructInput? continuum,
    ConstructInput? flow,
    ConstructInput? shear,
    ConstructInput? resistance,
    ConstructInput? vortex,
    bool? applyLevers,
  }) =>
      ScenarioInput(
        topic: topic ?? this.topic,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        posedQuestion: posedQuestion ?? this.posedQuestion,
        outcomeContext: outcomeContext ?? this.outcomeContext,
        outcomeParts: outcomeParts ?? this.outcomeParts,
        multiPartOutcomeEnabled:
            multiPartOutcomeEnabled ?? this.multiPartOutcomeEnabled,
        activePathwayLabel: activePathwayLabel ?? this.activePathwayLabel,
        siblingPathwayLabels: siblingPathwayLabels ?? this.siblingPathwayLabels,
        parentPosedQuestion: parentPosedQuestion ?? this.parentPosedQuestion,
        pathwayConstruals: pathwayConstruals ?? this.pathwayConstruals,
        continuumText: continuumText ?? this.continuumText,
        vortexText: vortexText ?? this.vortexText,
        shearText: shearText ?? this.shearText,
        resistanceText: resistanceText ?? this.resistanceText,
        flowText: flowText ?? this.flowText,
        continuum: continuum ?? this.continuum,
        flow: flow ?? this.flow,
        shear: shear ?? this.shear,
        resistance: resistance ?? this.resistance,
        vortex: vortex ?? this.vortex,
        applyLevers: applyLevers ?? this.applyLevers,
      );

  static String clamp(String text) =>
      text.length <= kFieldMaxLength ? text : text.substring(0, kFieldMaxLength);

  static String? _extractQuestionLine(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final q = t.indexOf('?');
    if (q >= 0) {
      final start = t.lastIndexOf(RegExp(r'[.!?\n]'), q - 1) + 1;
      return t.substring(start, q + 1).trim();
    }
    return t;
  }
}