enum AnalysisMode {
  cohesionScore,
  percentChance,
}

extension AnalysisModeWire on AnalysisMode {
  String get wireName => switch (this) {
        AnalysisMode.cohesionScore => 'cohesionScore',
        AnalysisMode.percentChance => 'percentChance',
      };

  static AnalysisMode fromWire(String raw) => switch (raw) {
        'cohesionScore' => AnalysisMode.cohesionScore,
        'percentChance' => AnalysisMode.percentChance,
        _ => AnalysisMode.percentChance,
      };
}

extension AnalysisModeLabel on AnalysisMode {
  String get title => switch (this) {
        AnalysisMode.percentChance => 'Percent Chance',
        AnalysisMode.cohesionScore => 'Social Cohesion Score',
      };

  String get subtitle => switch (this) {
        AnalysisMode.percentChance =>
          'Calculate event probability — @grok-style Chronoflux output',
        AnalysisMode.cohesionScore =>
          'Full PART ONE / TWO / THREE cohesion analysis report',
      };
}