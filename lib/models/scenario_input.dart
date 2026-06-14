import 'construct_input.dart';

const int kFieldMaxLength = 5000;
const String kPartTwoCommand = 'RUN PART TWO';
const String kPartThreeCommand = 'RUN PART THREE';

class ScenarioInput {
  const ScenarioInput({
    this.topic = '',
    this.sourceUrl = '',
    this.posedQuestion = '',
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
  bool get hasQuestion => posedQuestion.trim().isNotEmpty;

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

  /// Primary query text — posed question, with legacy vortex fallback.
  String get scenarioQuery {
    final posed = posedQuestion.trim();
    if (posed.isNotEmpty) return posed;
    return vortexText.trim();
  }

  String? get posedQuestionLine => _extractQuestionLine(scenarioQuery);

  /// Legacy alias — conclusions reference the posed question.
  String? get vortexQuestion => posedQuestionLine;

  ScenarioInput copyWith({
    String? topic,
    String? sourceUrl,
    String? posedQuestion,
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