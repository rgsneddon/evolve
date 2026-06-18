import '../models/grok_session.dart';

/// ω/σ/Iτ/Jμ construal scoped to one multi-part outcome pathway.
class PathwayConstructTexts {
  const PathwayConstructTexts({
    this.vortexText = '',
    this.shearText = '',
    this.resistanceText = '',
    this.flowText = '',
  });

  final String vortexText;
  final String shearText;
  final String resistanceText;
  final String flowText;

  bool get isEmpty =>
      vortexText.trim().isEmpty &&
      shearText.trim().isEmpty &&
      resistanceText.trim().isEmpty &&
      flowText.trim().isEmpty;

  bool get isNotEmpty => !isEmpty;

  factory PathwayConstructTexts.fromGrok(GrokConstrualResult result) =>
      PathwayConstructTexts(
        vortexText: result.vortexText,
        shearText: result.shearText,
        resistanceText: result.resistanceText,
        flowText: result.flowText,
      );

  String textFor(String constructKey) => switch (constructKey) {
        'vortex' => vortexText,
        'shear' => shearText,
        'resistance' => resistanceText,
        'flow' => flowText,
        _ => '',
      };

  PathwayConstructTexts copyWith({
    String? vortexText,
    String? shearText,
    String? resistanceText,
    String? flowText,
  }) =>
      PathwayConstructTexts(
        vortexText: vortexText ?? this.vortexText,
        shearText: shearText ?? this.shearText,
        resistanceText: resistanceText ?? this.resistanceText,
        flowText: flowText ?? this.flowText,
      );
}