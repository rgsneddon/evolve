import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'chronoflux_weight_construal.dart';
import 'scenario_calculation_context.dart';

/// Formats output like @grok X thread replies — in the user's language.
class GrokStyleFormatter {
  const GrokStyleFormatter({this.weightConstrual = const ChronofluxWeightConstrual()});

  final ChronofluxWeightConstrual weightConstrual;

  String format({
    required ScenarioInput input,
    required HydrodynamicCore core,
    required String continuumConclusion,
    required LocalizedOutput output,
    LocaleConfig locale = LocaleConfig.defaults,
  }) {
    final weightResult = weightConstrual.construeFromContext(
      ScenarioCalculationContext.from(
        input: input,
        regionId: locale.regionId,
      ),
    );
    final momentum = core.netMomentum >= 0
        ? '+${core.netMomentum.toStringAsFixed(3)}'
        : core.netMomentum.toStringAsFixed(3);

    return output.grokReply(
      weights: weightResult.summary,
      weightConstrual: output.weightConstrualLine(weightResult.reasonKeys),
      continuum: core.continuumScs.round(),
      flow: core.flowScs.round(),
      shear: core.shearScs.round(),
      resistance: core.resistanceScs.round(),
      vortex: core.vortexScs.round(),
      overallScs: core.overallScs,
      refinedScs: core.refinedScs,
      regressivePct: core.regressivePct,
      progressivePct: core.progressivePct,
      momentum: momentum,
      lean: core.lean,
      continuumConclusion: continuumConclusion,
    );
  }
}