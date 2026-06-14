import '../models/scenario_input.dart';
import 'field_calculation_context.dart';
import 'question_semantics.dart';
import 'scenario_calculation_context.dart';

/// Ascertains Chronoflux wᵢ from scenario + field **context** and continuum **lean**.
///
/// Construct order (FrameworkSpec): [ρt continuum, Jμ flow, σ shear, Iτ resistance, ω vortex]
class ChronofluxWeightResult {
  const ChronofluxWeightResult({
    required this.rawWeights,
    required this.normalized,
    required this.summary,
    required this.reasonKeys,
  });

  final List<double> rawWeights;
  final List<double> normalized;
  final String summary;
  final List<String> reasonKeys;
}

class ChronofluxWeightConstrual {
  const ChronofluxWeightConstrual();

  static const _symbols = ['ρt', 'Jμ', 'σ', 'Iτ', 'ω'];

  ChronofluxWeightResult construe(
    ScenarioInput input, {
    String regionId = 'global',
    String? lean,
  }) =>
      construeFromContext(
        ScenarioCalculationContext.from(
          input: input,
          regionId: regionId,
          lean: lean,
        ),
      );

  ChronofluxWeightResult construeFromContext(ScenarioCalculationContext ctx) {
    final w = List<double>.filled(5, 1.0);
    final reasons = <String>[];

    if (ctx.hasPosedQuestion) {
      w[4] += 2.5;
      reasons.add('weight_reason_posed_question');
    }
    if (ctx.hasTopic) {
      w[0] += 1.0;
      reasons.add('weight_reason_topic');
    }
    if (ctx.regionId != 'global') {
      w[4] += 0.8;
      reasons.add('weight_reason_regional');
    }

    _applyFrameContext(ctx.frame, w, reasons);
    _applyEventClassContext(ctx.eventClass, w, reasons);
    _applyHorizonContext(ctx.horizonDays, w, reasons);
    _applyFieldContext(ctx.fields, w, reasons);

    if (ctx.isRegressiveLean) {
      w[2] *= 1.38;
      w[3] *= 1.28;
      w[1] *= 0.86;
      w[4] *= 1.08;
      reasons.add('weight_reason_lean_regressive');
    } else if (ctx.isProgressiveLean) {
      w[1] *= 1.38;
      w[4] *= 1.22;
      w[2] *= 0.86;
      w[3] *= 0.9;
      reasons.add('weight_reason_lean_progressive');
    }

    w[0] *= ctx.hasTopic ? 1.1 : 0.9;

    final total = w.fold(0.0, (a, x) => a + x);
    final norm = w.map((x) => x / total).toList();

    return ChronofluxWeightResult(
      rawWeights: w,
      normalized: norm,
      summary: _formatSummary(norm),
      reasonKeys: reasons.toSet().toList(),
    );
  }

  void _applyFrameContext(
    QuestionFrame frame,
    List<double> w,
    List<String> reasons,
  ) {
    switch (frame) {
      case QuestionFrame.probability:
        w[4] += 0.5;
        w[1] += 0.35;
        reasons.add('weight_reason_probability');
      case QuestionFrame.magnitude:
        w[1] += 0.55;
        w[4] += 0.3;
        reasons.add('weight_reason_magnitude');
      case QuestionFrame.predictive:
        w[4] += 0.4;
        w[3] += 0.35;
        reasons.add('weight_reason_predictive');
      case QuestionFrame.descriptive:
        w[0] += 0.45;
        reasons.add('weight_reason_descriptive');
    }
  }

  void _applyEventClassContext(
    String eventClass,
    List<double> w,
    List<String> reasons,
  ) {
    switch (eventClass) {
      case 'civil_unrest':
        w[2] += 0.85;
        w[4] += 0.55;
        reasons.add('weight_reason_context_unrest');
      case 'recession':
        w[3] += 0.75;
        w[4] += 0.35;
        reasons.add('weight_reason_context_economic');
      case 'election_upset':
        w[4] += 0.65;
        w[2] += 0.45;
        reasons.add('weight_reason_context_electoral');
      case 'cohesion_decline':
        w[1] += 0.5;
        w[3] += 0.45;
        reasons.add('weight_reason_context_cohesion');
      case 'policy_passage':
        w[3] += 0.8;
        reasons.add('weight_reason_context_institutional');
      default:
        w[0] += 0.35;
        reasons.add('weight_reason_context_general');
    }
  }

  void _applyFieldContext(
    FieldCalculationContext fields,
    List<double> w,
    List<String> reasons,
  ) {
    if (fields.hasVortexVariable) {
      w[4] += 1.2;
      reasons.add('weight_reason_vortex_variable');
    } else if (fields.hasVortexAnchorOnly) {
      w[4] += 1.2;
      reasons.add('weight_reason_vortex');
    }
    if (fields.hasShear) {
      w[2] += 2.0;
      reasons.add('weight_reason_shear');
    }
    if (fields.hasResistance) {
      w[3] += 2.0;
      reasons.add('weight_reason_resistance');
    }
    if (fields.hasFlow) {
      w[1] += 2.0;
      reasons.add('weight_reason_flow');
    }

    if (!fields.hasFlow) w[1] *= 0.72;
    if (!fields.hasShear) w[2] *= 0.72;
    if (!fields.hasResistance) w[3] *= 0.72;
  }

  void _applyHorizonContext(int horizonDays, List<double> w, List<String> reasons) {
    if (horizonDays <= 30) {
      w[2] += 0.45;
      reasons.add('weight_reason_context_immediate');
    } else if (horizonDays <= 90) {
      w[4] += 0.25;
      reasons.add('weight_reason_context_near_term');
    } else if (horizonDays >= 365) {
      w[3] += 0.35;
      reasons.add('weight_reason_context_annual');
    }
  }

  ScenarioInput apply(ScenarioInput input, ChronofluxWeightResult result) {
    final c = input.constructs;
    return input.copyWith(
      continuum: c[0].copyWith(weight: result.rawWeights[0]),
      flow: c[1].copyWith(weight: result.rawWeights[1]),
      shear: c[2].copyWith(weight: result.rawWeights[2]),
      resistance: c[3].copyWith(weight: result.rawWeights[3]),
      vortex: c[4].copyWith(weight: result.rawWeights[4]),
    );
  }

  String _formatSummary(List<double> norm) {
    final parts = <String>[];
    for (var i = 0; i < 5; i++) {
      parts.add('${_symbols[i]}=${norm[i].toStringAsFixed(2)}');
    }
    return parts.join(' ');
  }
}