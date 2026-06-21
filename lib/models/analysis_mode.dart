enum AnalysisMode {
  cohesionScore,
  percentChance,
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