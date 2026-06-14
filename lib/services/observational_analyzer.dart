import '../l10n/localized_output.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'question_semantics.dart';
import 'region_context.dart';

class FieldObservation {
  const FieldObservation({required this.scs, required this.narrative});

  final double scs;
  final String narrative;
}

/// Infer ω/σ/Iτ/Jμ — narratives in the user's selected language.
class ObservationalAnalyzer {
  const ObservationalAnalyzer();

  double questionFingerprint(String text) =>
      QuestionSemantics.fromText(text).fingerprint;

  FieldObservation observeVortex(
    ScenarioInput input, {
    LocaleConfig locale = LocaleConfig.defaults,
    LocalizedOutput? output,
  }) {
    final out = output ?? LocalizedOutput.of(locale);
    final regionLabel = out.regionName(locale.regionId);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: regionLabel,
    );
    var scs = sem.vortexOffset;
    final vortexVar = input.vortexText.trim();
    if (vortexVar.isNotEmpty) {
      final relative = QuestionSemantics.fromText(
        vortexVar,
        regionId: locale.regionId,
        regionLabel: regionLabel,
      );
      scs = (scs * 0.5 + relative.vortexOffset * 0.5);
    }
    scs = scs.clamp(38.0, 82.0);

    final scopedVortex = vortexVar.isNotEmpty
        ? RegionContext(locale.regionId).scopeFieldText(vortexVar, regionLabel)
        : vortexVar;

    final narrative = vortexVar.isNotEmpty
        ? out.observedVortexRelative(
            sem.displaySubject,
            scopedVortex,
            scs.round(),
            regionLabel,
          )
        : out.observedVortex(
            sem.displaySubject,
            scs.round(),
            out.regionName(locale.regionId),
          );

    return FieldObservation(scs: scs, narrative: narrative);
  }

  Map<String, FieldObservation> observeBlanks(
    ScenarioInput input, {
    LocaleConfig locale = LocaleConfig.defaults,
    LocalizedOutput? output,
  }) {
    if (!input.hasQuestion && input.scenarioQuery.isEmpty) return {};
    final out = output ?? LocalizedOutput.of(locale);
    final regionLabel = out.regionName(locale.regionId);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: regionLabel,
    );
    final result = <String, FieldObservation>{};

    if (input.shearText.trim().isEmpty) {
      result['shear'] = _observeShear(sem, out, locale.regionId);
    }
    if (input.resistanceText.trim().isEmpty) {
      result['resistance'] = _observeResistance(sem, out, locale.regionId);
    }
    if (input.flowText.trim().isEmpty) {
      result['flow'] = _observeFlow(sem, out, locale.regionId);
    }
    return result;
  }

  FieldObservation _observeShear(
    QuestionSemantics sem,
    LocalizedOutput out,
    String regionId,
  ) {
    final scs = sem.shearOffset.clamp(42.0, 78.0);
    return FieldObservation(
      scs: scs,
      narrative: out.observedShear(
        sem.displaySubject,
        scs.round(),
        out.regionName(regionId),
      ),
    );
  }

  FieldObservation _observeResistance(
    QuestionSemantics sem,
    LocalizedOutput out,
    String regionId,
  ) {
    final scs = sem.resistanceOffset.clamp(40.0, 74.0);
    return FieldObservation(
      scs: scs,
      narrative: out.observedResistance(
        sem.displaySubject,
        scs.round(),
        out.regionName(regionId),
      ),
    );
  }

  FieldObservation _observeFlow(
    QuestionSemantics sem,
    LocalizedOutput out,
    String regionId,
  ) {
    final scs = sem.flowOffset.clamp(32.0, 68.0);
    return FieldObservation(
      scs: scs,
      narrative: out.observedFlow(
        sem.displaySubject,
        scs.round(),
        out.regionName(regionId),
      ),
    );
  }
}