import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/evolve_result.dart';

/// Formats percent-chance output like @grok X thread replies — lean on THE CONTINUUM only.
class GrokStyleFormatter {
  const GrokStyleFormatter();

  String format({
    required HydrodynamicCore core,
    required String continuumConclusion,
    required LocalizedOutput output,
  }) {
    final momentum = core.netMomentum >= 0
        ? '+${core.netMomentum.toStringAsFixed(3)}'
        : core.netMomentum.toStringAsFixed(3);

    return output.grokReply(
      regressivePct: core.regressivePct,
      progressivePct: core.progressivePct,
      momentum: momentum,
      lean: core.lean,
      continuumConclusion: continuumConclusion,
    );
  }
}