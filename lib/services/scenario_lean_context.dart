import '../l10n/app_localizations.dart';
import '../models/evolve_result.dart';
import 'question_semantics.dart';

/// How THE CONTINUUM lean (PROGRESSIVE / REGRESSIVE) governs all recommendations.
class ScenarioLeanContext {
  const ScenarioLeanContext({
    required this.lean,
    required this.polarity,
    required this.regressivePct,
    required this.progressivePct,
    required this.netMomentum,
  });

  final String lean;
  final OutcomePolarity polarity;
  final double regressivePct;
  final double progressivePct;
  final double netMomentum;

  bool get isRegressive => lean == 'REGRESSIVE';
  bool get isProgressive => lean == 'PROGRESSIVE';

  /// REGRESSIVE lean or adverse ω polarity — do not recommend raising scenario likelihood.
  bool get mitigateScenario => isRegressive || polarity == OutcomePolarity.adverse;

  /// PROGRESSIVE lean on a non-adverse scenario — sustain constructive momentum.
  bool get supportScenario =>
      isProgressive && polarity != OutcomePolarity.adverse;

  factory ScenarioLeanContext.from({
    required HydrodynamicCore core,
    required QuestionSemantics sem,
  }) =>
      ScenarioLeanContext(
        lean: core.lean,
        polarity: sem.polarity,
        regressivePct: core.regressivePct,
        progressivePct: core.progressivePct,
        netMomentum: core.netMomentum,
      );

  String leanLabel(AppLocalizations strings) =>
      strings.t(isProgressive ? 'lean_progressive' : 'lean_regressive');

  String understandingLine(AppLocalizations strings) {
    if (mitigateScenario) {
      return strings
          .t('continuum_understand_mitigate')
          .replaceAll('{lean}', leanLabel(strings))
          .replaceAll('{reg}', '${regressivePct.round()}')
          .replaceAll('{prog}', '${progressivePct.round()}');
    }
    return strings
        .t('continuum_understand_support')
        .replaceAll('{lean}', leanLabel(strings))
        .replaceAll('{reg}', '${regressivePct.round()}')
        .replaceAll('{prog}', '${progressivePct.round()}');
  }

  String bindingLeanTag(AppLocalizations strings) => strings
      .t('bind_continuum_lean')
      .replaceAll('{lean}', leanLabel(strings))
      .replaceAll('{reg}', '${regressivePct.round()}')
      .replaceAll('{prog}', '${progressivePct.round()}');

  /// Shift regressive transport down or build progressive transport up.
  int progressiveShiftPercent(double current, int actionCount) {
    final lift = (actionCount * 2.2).clamp(4.0, 10.0);
    if (mitigateScenario) {
      return (current - lift).clamp(8, 92).round();
    }
    return (current + lift).clamp(8, 92).round();
  }
}