class PartThreeAction {
  const PartThreeAction({
    required this.action,
    this.construct = '',
    this.rationale = '',
  });

  final String action;
  final String construct;
  final String rationale;
}

class PartThreeConclusion {
  const PartThreeConclusion({
    required this.headline,
    required this.agentLabel,
    required this.contextLine,
    required this.inputBinding,
    required this.actions,
    required this.projectedImpact,
    required this.targetLabel,
  });

  final String headline;
  final String agentLabel;
  final String contextLine;
  final String inputBinding;
  final List<PartThreeAction> actions;
  final String projectedImpact;
  final String targetLabel;

  @Deprecated('Use contextLine')
  String get scenarioRead => contextLine;
}