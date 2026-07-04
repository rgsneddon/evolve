import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'event_classifier.dart';
import 'field_calculation_context.dart';
import 'outcome_feasibility.dart';
import 'question_semantics.dart';

/// Scenario + field **context** for Chronoflux — not σ/Iτ/Jμ field prose keywords.
class ScenarioCalculationContext {
  const ScenarioCalculationContext({
    required this.regionId,
    required this.hasPosedQuestion,
    required this.hasTopic,
    required this.frame,
    required this.polarity,
    required this.eventClass,
    required this.horizonDays,
    required this.fields,
    this.lean,
  });

  final String regionId;
  final bool hasPosedQuestion;
  final bool hasTopic;
  final QuestionFrame frame;
  final OutcomePolarity polarity;
  final String eventClass;
  final int horizonDays;
  final FieldCalculationContext fields;
  final String? lean;

  /// Lean for weight construal — explicit override or inferred from context only.
  String get effectiveLean => lean ?? _inferLeanFromContext();

  bool get isRegressiveLean => effectiveLean == 'REGRESSIVE';
  bool get isProgressiveLean => effectiveLean == 'PROGRESSIVE';

  /// Context anchor — posed question, region, topic, and structural frame only.
  factory ScenarioCalculationContext.from({
    required ScenarioInput input,
    String regionId = 'global',
    String? lean,
  }) {
    final sem = QuestionSemantics.parse(input, regionId: regionId);
    final classification = const EventClassifier().classify(
      input,
      regionId: regionId,
    );
    final feasibility = const OutcomeFeasibilityChecker().check(
      input,
      regionId: regionId,
    );
    final resolvedLean = lean ??
        (feasibility.isForeclosed ? 'REGRESSIVE' : null);
    return ScenarioCalculationContext(
      regionId: regionId,
      hasPosedQuestion: input.scenarioQuery.trim().isNotEmpty,
      hasTopic: input.topic.trim().isNotEmpty,
      frame: sem.frame,
      polarity: sem.polarity,
      eventClass: classification.eventClass,
      horizonDays: classification.horizonDays,
      fields: FieldCalculationContext.from(input),
      lean: resolvedLean,
    );
  }

  String _inferLeanFromContext() {
    final base = _inferLeanFromScenario();
    if (fields.hasShear && fields.hasResistance && !fields.hasFlow) {
      return 'REGRESSIVE';
    }
    if (fields.hasFlow && !fields.hasShear && !fields.hasResistance) {
      return 'PROGRESSIVE';
    }
    return base;
  }

  String _inferLeanFromScenario() {
    switch (eventClass) {
      case 'civil_unrest':
      case 'recession':
      case 'election_upset':
        return 'REGRESSIVE';
      case 'cohesion_decline':
        return polarity == OutcomePolarity.favourable
            ? 'PROGRESSIVE'
            : 'REGRESSIVE';
      case 'policy_passage':
        return 'PROGRESSIVE';
      default:
        return switch (polarity) {
          OutcomePolarity.favourable => 'PROGRESSIVE',
          OutcomePolarity.adverse => 'REGRESSIVE',
          OutcomePolarity.open => 'PROGRESSIVE',
        };
    }
  }

  /// Scenario anchor + topic only — question-level context without construct variables.
  ScenarioInput contextOnly(ScenarioInput input) => ScenarioInput(
        posedQuestion: input.scenarioQuery,
        topic: input.topic,
        sourceUrl: input.sourceUrl,
        applyLevers: input.applyLevers,
      );

  /// Scenario anchor + supplied construct field variables for SCS field context.
  ScenarioInput withFieldContext(ScenarioInput input) => ScenarioInput(
        posedQuestion: input.scenarioQuery,
        topic: input.topic,
        sourceUrl: input.sourceUrl,
        applyLevers: input.applyLevers,
        vortexText: input.vortexText,
        shearText: input.shearText,
        resistanceText: input.resistanceText,
        flowText: input.flowText,
      );
}