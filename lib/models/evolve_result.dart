import 'conclusion_explainer_data.dart';
import 'forecast_result.dart';
import 'part_percent_breakdown.dart';
import 'part_three_conclusion.dart';
import 'party_response_scs.dart';

class HydrodynamicCore {
  const HydrodynamicCore({
    required this.overallScs,
    required this.baselineScs,
    required this.refinedScs,
    required this.progressivePct,
    required this.regressivePct,
    required this.netMomentum,
    required this.lean,
    required this.continuumScs,
    required this.flowScs,
    required this.shearScs,
    required this.resistanceScs,
    required this.vortexScs,
    this.positive = 0,
    this.dissipative = 0,
  });

  final double overallScs;
  final double baselineScs;
  final double refinedScs;
  final double progressivePct;
  final double regressivePct;
  final double netMomentum;
  final String lean;
  final double continuumScs;
  final double flowScs;
  final double shearScs;
  final double resistanceScs;
  final double vortexScs;
  final double positive;
  final double dissipative;
}

class PartOneSection {
  const PartOneSection({
    required this.vortex,
    required this.shear,
    required this.resistance,
    required this.flow,
    required this.overallScs,
    required this.baselineScs,
    required this.progressivePct,
    required this.regressivePct,
  });

  final String vortex;
  final String shear;
  final String resistance;
  final String flow;
  final double overallScs;
  final double baselineScs;
  final double progressivePct;
  final double regressivePct;
}

class PartTwoSection {
  const PartTwoSection({
    required this.core,
    required this.expandedVortex,
    required this.shearRefinement,
    required this.resistanceFlow,
    required this.refinedScs,
    required this.progressivePct,
    required this.regressivePct,
    required this.lean,
  });

  final HydrodynamicCore core;
  final String expandedVortex;
  final String shearRefinement;
  final String resistanceFlow;
  final double refinedScs;
  final double progressivePct;
  final double regressivePct;
  final String lean;
}

class PartThreeSection {
  const PartThreeSection({
    required this.interventions,
    required this.withoutLeversScs,
    required this.withLeversMin,
    required this.withLeversMax,
    required this.recurrenceRisk,
  });

  final List<String> interventions;
  final double withoutLeversScs;
  final double withLeversMin;
  final double withLeversMax;
  final String recurrenceRisk;
}

class EvolveResult {
  const EvolveResult({
    required this.core,
    required this.partOne,
    required this.partTwo,
    required this.partThree,
    required this.percentChance,
    required this.percentPhrase,
    required this.continuumConclusion,
    required this.grokStyleReply,
    required this.cohesionReport,
    required this.partThreeConclusion,
    required this.forecast,
    required this.explainerData,
    this.partyRefinement,
    this.partBreakdown,
    this.partTwoRan = true,
  });

  final HydrodynamicCore core;
  final PartOneSection partOne;
  final PartTwoSection partTwo;
  final bool partTwoRan;
  final PartThreeSection partThree;
  final double percentChance;
  final String percentPhrase;
  final String continuumConclusion;
  final String grokStyleReply;
  final String cohesionReport;
  final PartThreeConclusion partThreeConclusion;
  final ForecastResult forecast;
  final ConclusionExplainerData explainerData;
  final NarrativePartyRefinement? partyRefinement;
  final PartPercentBreakdown? partBreakdown;
}