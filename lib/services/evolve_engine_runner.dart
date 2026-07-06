import 'package:flutter/foundation.dart';

import '../models/analysis_mode.dart';
import '../models/evolve_result.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'evolve_engine.dart';

/// Maximum attributed party quotes scored during cohesion URL refinement.
const int kMaxPartyResponseFragments = 4;

@immutable
class EvolveAnalyzeParams {
  const EvolveAnalyzeParams({
    required this.input,
    required this.mode,
    required this.locale,
  });

  final ScenarioInput input;
  final AnalysisMode mode;
  final LocaleConfig locale;
}

EvolveResult evolveAnalyzeSync(EvolveAnalyzeParams params) {
  return const EvolveEngine().analyze(
    params.input,
    mode: params.mode,
    locale: params.locale,
  );
}

Future<EvolveResult> runEvolveAnalyze({
  required ScenarioInput input,
  required AnalysisMode mode,
  required LocaleConfig locale,
}) async {
  final params = EvolveAnalyzeParams(
    input: input,
    mode: mode,
    locale: locale,
  );
  if (kIsWeb) {
    return evolveAnalyzeSync(params);
  }
  return compute(evolveAnalyzeSync, params);
}