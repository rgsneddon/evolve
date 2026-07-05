import '../../models/analysis_mode.dart';
import '../../models/evolve_result.dart';
import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../../services/evolve_engine.dart';

class FcgPolicyAnalysis {
  const FcgPolicyAnalysis({
    this.cohesionResult,
    this.percentResult,
  });

  final EvolveResult? cohesionResult;
  final EvolveResult? percentResult;

  double? get cohesionScs => cohesionResult?.core.refinedScs;
  double? get percentChance => percentResult?.percentChance;

  String get cohesionNarrative =>
      cohesionResult?.cohesionReport.trim() ?? '';

  String get percentNarrative {
    final result = percentResult;
    if (result == null) return '';
    final phrase = result.percentPhrase.trim();
    if (phrase.isNotEmpty) return phrase;
    return result.continuumConclusion.trim();
  }
}

/// Runs Chronoflux analysis for a ward policy question.
class FcgPolicyAnalyzer {
  const FcgPolicyAnalyzer({EvolveEngine? engine})
      : _engine = engine ?? const EvolveEngine();

  final EvolveEngine _engine;

  FcgPolicyAnalysis analyze({
    required String policyQuestion,
    required LocaleConfig locale,
    required bool runCohesion,
    required bool runPercent,
  }) {
    final base = ScenarioInput(posedQuestion: policyQuestion.trim());

    EvolveResult? cohesion;
    EvolveResult? percent;

    if (runCohesion) {
      cohesion = _engine.analyze(
        base,
        locale: locale,
        mode: AnalysisMode.cohesionScore,
      );
    }
    if (runPercent) {
      percent = _engine.analyze(
        base,
        locale: locale,
        mode: AnalysisMode.percentChance,
      );
    }

    return FcgPolicyAnalysis(
      cohesionResult: cohesion,
      percentResult: percent,
    );
  }
}