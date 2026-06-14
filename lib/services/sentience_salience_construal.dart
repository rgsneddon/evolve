import 'question_semantics.dart';
import 'scenario_calculation_context.dart';

/// Chronoflux awareness channels — sentience reacts as shear (σ); salience reacts as resistance (Iτ).
class SentienceSalienceResult {
  const SentienceSalienceResult({
    required this.sentiencePct,
    required this.saliencePct,
    required this.shearReaction,
    required this.resistanceReaction,
    required this.reasonKeys,
  });

  /// Scenario-aware polarisation perception (σ channel).
  final double sentiencePct;

  /// Scenario-aware institutional attention (Iτ channel).
  final double saliencePct;

  /// Multiplier applied to effective σ in the dissipative core.
  final double shearReaction;

  /// Multiplier applied to effective Iτ in the dissipative core.
  final double resistanceReaction;

  final List<String> reasonKeys;
}

class SentienceSalienceConstrual {
  const SentienceSalienceConstrual();

  static const reactionFloor = 0.45;
  static const reactionCeiling = 1.0;

  SentienceSalienceResult construe({
    required ScenarioCalculationContext context,
    required List<double> normalizedWeights,
    required QuestionSemantics semantics,
  }) {
    final reasons = <String>[];

    var sentience = normalizedWeights[2] * 100;
    var salience = normalizedWeights[3] * 100;

    if (context.fields.hasShear) {
      sentience += 12;
      reasons.add('sentience_reason_field_shear');
    }
    if (context.fields.hasResistance) {
      salience += 12;
      reasons.add('salience_reason_field_resistance');
    }

    switch (context.eventClass) {
      case 'civil_unrest':
        sentience += 16;
        reasons.add('sentience_reason_unrest');
      case 'election_upset':
        sentience += 9;
        salience += 5;
        reasons.add('sentience_reason_electoral');
      case 'recession':
        salience += 15;
        reasons.add('salience_reason_economic');
      case 'policy_passage':
        salience += 14;
        reasons.add('salience_reason_institutional');
      case 'cohesion_decline':
        sentience += 6;
        salience += 8;
        reasons.add('salience_reason_cohesion');
      default:
        break;
    }

    switch (context.frame) {
      case QuestionFrame.probability:
        sentience += 7;
        reasons.add('sentience_reason_probability');
      case QuestionFrame.magnitude:
        sentience += 8;
        reasons.add('sentience_reason_magnitude');
      case QuestionFrame.predictive:
        salience += 6;
        reasons.add('salience_reason_predictive');
      case QuestionFrame.descriptive:
        salience += 4;
        reasons.add('salience_reason_descriptive');
    }

    switch (context.polarity) {
      case OutcomePolarity.adverse:
        sentience += 11;
        reasons.add('sentience_reason_adverse');
      case OutcomePolarity.favourable:
        salience += 5;
        reasons.add('salience_reason_favourable');
      case OutcomePolarity.open:
        break;
    }

    if (context.horizonDays <= 30) {
      sentience += 5;
      reasons.add('sentience_reason_immediate');
    } else if (context.horizonDays >= 365) {
      salience += 10;
      reasons.add('salience_reason_annual');
    }

    sentience += (semantics.shearOffset - 50) * 0.18;
    salience += (semantics.resistanceOffset - 50) * 0.18;

    for (final hint in semantics.hintSignals) {
      final lower = hint.toLowerCase();
      if (lower.contains('disorder') ||
          lower.contains('narrative') ||
          lower.contains('electoral')) {
        sentience += 4;
        reasons.add('sentience_reason_signal');
      }
      if (lower.contains('economic') || lower.contains('institutional')) {
        salience += 4;
        reasons.add('salience_reason_signal');
      }
    }

    sentience = sentience.clamp(8, 92);
    salience = salience.clamp(8, 92);

    final shearReaction = _reaction(sentience);
    final resistanceReaction = _reaction(salience);

    return SentienceSalienceResult(
      sentiencePct: sentience,
      saliencePct: salience,
      shearReaction: shearReaction,
      resistanceReaction: resistanceReaction,
      reasonKeys: reasons.toSet().toList(),
    );
  }

  static double _reaction(double pct) =>
      reactionFloor + (reactionCeiling - reactionFloor) * (pct / 100);
}