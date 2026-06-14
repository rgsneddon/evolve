import '../l10n/localized_output.dart';
import '../models/construct_input.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'chronoflux_weight_construal.dart';
import 'observational_analyzer.dart';
import 'question_semantics.dart';
import 'region_context.dart';
import 'scenario_calculation_context.dart';

class InputParser {
  const InputParser({
    this.observational = const ObservationalAnalyzer(),
    this.weightConstrual = const ChronofluxWeightConstrual(),
  });

  final ObservationalAnalyzer observational;
  final ChronofluxWeightConstrual weightConstrual;

  ScenarioInput enrich(
    ScenarioInput raw, {
    LocaleConfig locale = LocaleConfig.defaults,
    LocalizedOutput? output,
  }) {
    final out = output ?? LocalizedOutput.of(locale);
    final ctx = ScenarioCalculationContext.from(
      input: raw,
      regionId: locale.regionId,
    );
    final questionInput = ctx.contextOnly(raw);
    final fieldInput = ctx.withFieldContext(raw);
    final questionSem = QuestionSemantics.parse(
      questionInput,
      regionId: locale.regionId,
      regionLabel: out.regionName(locale.regionId),
    );

    final vortexObs = observational.observeVortex(
      fieldInput,
      locale: locale,
      output: out,
    );
    final obs = observational.observeBlanks(
      questionInput,
      locale: locale,
      output: out,
    );

    final withScs = raw.copyWith(
      vortex: raw.vortex.copyWith(
        scs: _scsForVortex(raw.vortexText, vortexObs.scs),
      ),
      shear: raw.shear.copyWith(
        scs: _scsFromFieldContext(
          raw.shearText,
          obs['shear']?.scs ?? questionSem.shearOffset,
          questionOffset: questionSem.shearOffset,
          clampMin: 42,
          clampMax: 78,
          locale: locale,
        ),
      ),
      resistance: raw.resistance.copyWith(
        scs: _scsFromFieldContext(
          raw.resistanceText,
          obs['resistance']?.scs ?? questionSem.resistanceOffset,
          questionOffset: questionSem.resistanceOffset,
          clampMin: 40,
          clampMax: 74,
          locale: locale,
        ),
      ),
      flow: raw.flow.copyWith(
        scs: _scsFromFieldContext(
          raw.flowText,
          obs['flow']?.scs ?? questionSem.flowOffset,
          questionOffset: questionSem.flowOffset,
          clampMin: 32,
          clampMax: 68,
          locale: locale,
        ),
      ),
    );

    final contextLean = ctx.effectiveLean;
    final weights = weightConstrual.construeFromContext(
      ScenarioCalculationContext.from(
        input: raw,
        regionId: locale.regionId,
        lean: contextLean,
      ),
    );
    final weighted = weightConstrual.apply(withScs, weights);

    return weighted.copyWith(
      continuum: weighted.continuum.copyWith(
        scs: _continuumFromConstructs(weighted),
      ),
    );
  }

  Map<String, String> narratives(
    ScenarioInput input, {
    LocaleConfig locale = LocaleConfig.defaults,
    LocalizedOutput? output,
  }) {
    final out = output ?? LocalizedOutput.of(locale);
    final regionLabel = out.regionName(locale.regionId);
    final region = RegionContext(locale.regionId);
    final contextInput = ScenarioCalculationContext.from(
      input: input,
      regionId: locale.regionId,
    ).contextOnly(input);
    final vortexObs = observational.observeVortex(
      contextInput,
      locale: locale,
      output: out,
    );
    final obs = observational.observeBlanks(
      contextInput,
      locale: locale,
      output: out,
    );

    return {
      'vortex': input.vortexText.trim().isNotEmpty
          ? region.scopeFieldText(input.vortexText.trim(), regionLabel)
          : vortexObs.narrative,
      'shear': input.shearText.trim().isNotEmpty
          ? region.scopeFieldText(input.shearText.trim(), regionLabel)
          : (obs['shear']?.narrative ?? out.shearFallback()),
      'resistance': input.resistanceText.trim().isNotEmpty
          ? region.scopeFieldText(input.resistanceText.trim(), regionLabel)
          : (obs['resistance']?.narrative ?? out.resistanceFallback()),
      'flow': input.flowText.trim().isNotEmpty
          ? region.scopeFieldText(input.flowText.trim(), regionLabel)
          : (obs['flow']?.narrative ?? out.flowFallback()),
    };
  }

  /// ω SCS — observational analyzer already blends vortex field context.
  double _scsForVortex(String fieldText, double observed) {
    final explicit =
        RegExp(r'scs[:\s=]*(\d{1,3})', caseSensitive: false).firstMatch(fieldText.trim());
    if (explicit != null) {
      return double.parse(explicit.group(1)!).clamp(0, 100);
    }
    return observed.clamp(38, 82);
  }

  /// SCS from scenario context; supplied σ/Iτ/Jμ fields contribute as construct variables.
  double _scsFromFieldContext(
    String fieldText,
    double questionFallback, {
    required double questionOffset,
    required double clampMin,
    required double clampMax,
    required LocaleConfig locale,
  }) {
    final t = fieldText.trim();
    if (t.isEmpty) return questionFallback.clamp(clampMin, clampMax);

    final explicit =
        RegExp(r'scs[:\s=]*(\d{1,3})', caseSensitive: false).firstMatch(t);
    if (explicit != null) {
      return double.parse(explicit.group(1)!).clamp(0, 100);
    }

    final fp = QuestionSemantics.fromText(t, regionId: locale.regionId).fingerprint;
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final presence = (words.clamp(4, 24) - 4) * 0.15;
    final variableOffset = questionOffset + fp * 0.35 + presence;
    return (questionOffset * 0.5 + variableOffset * 0.5).clamp(clampMin, clampMax);
  }

  double _continuumFromConstructs(ScenarioInput input) {
    final c = input.constructs;
    final w = _weights(c);
    var sum = 0.0;
    for (var i = 0; i < 5; i++) {
      sum += c[i].scs * w[i];
    }
    return sum.clamp(30, 80);
  }

  List<double> _weights(List<ConstructInput> c) {
    final total = c.fold(0.0, (a, x) => a + x.weight);
    if (total < 1e-9) return List.filled(5, 0.2);
    return c.map((x) => x.weight / total).toList();
  }
}