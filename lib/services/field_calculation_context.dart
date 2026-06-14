import '../models/scenario_input.dart';

/// Which construct fields the user supplied — structural context, not prose keywords.
class FieldCalculationContext {
  const FieldCalculationContext({
    required this.hasVortexVariable,
    required this.hasVortexAnchorOnly,
    required this.hasShear,
    required this.hasResistance,
    required this.hasFlow,
  });

  final bool hasVortexVariable;
  final bool hasVortexAnchorOnly;
  final bool hasShear;
  final bool hasResistance;
  final bool hasFlow;

  factory FieldCalculationContext.from(ScenarioInput input) {
    final anchor = input.scenarioQuery.trim();
    final vortex = input.vortexText.trim();
    final hasAnchor = anchor.isNotEmpty;
    final vortexIsAnchor = hasAnchor && vortex == anchor;

    return FieldCalculationContext(
      hasVortexVariable: vortex.isNotEmpty && hasAnchor && !vortexIsAnchor,
      hasVortexAnchorOnly: vortex.isNotEmpty && !hasAnchor,
      hasShear: input.shearText.trim().isNotEmpty,
      hasResistance: input.resistanceText.trim().isNotEmpty,
      hasFlow: input.flowText.trim().isNotEmpty,
    );
  }
}