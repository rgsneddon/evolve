import 'question_semantics.dart';
import 'region_context.dart';

/// Offline discourse-style construct lines — distinct per ω/σ/Iτ/Jμ, no question echo.
class GrokConstructDiscourse {
  const GrokConstructDiscourse._();

  static String forConstruct({
    required String construct,
    required String subject,
    required String region,
    required List<String> hintSignals,
    String? observationalNarrative,
  }) {
    final obs = observationalNarrative?.trim() ?? '';
    if (obs.isNotEmpty && !obs.toLowerCase().startsWith('posed question:')) {
      return _clamp(obs, 500);
    }
    return _clamp(_line(construct, subject, region, hintSignals), 500);
  }

  static String fromQuestion({
    required String construct,
    required String posedQuestion,
    required String regionId,
    String? regionLabel,
    String? observationalNarrative,
  }) {
    final sem = QuestionSemantics.fromText(
      posedQuestion,
      regionId: regionId,
      regionLabel: regionLabel,
    );
    return forConstruct(
      construct: construct,
      subject: sem.displaySubject,
      region: regionLabel ?? RegionContext.englishLabel(regionId),
      hintSignals: sem.hintSignals,
      observationalNarrative: observationalNarrative,
    );
  }

  static String _line(
    String construct,
    String subject,
    String region,
    List<String> hints,
  ) {
    final hint = hints.isNotEmpty ? hints.first.toLowerCase() : '';
    return switch (construct) {
      'vortex' => _vortex(subject, region, hint),
      'shear' => _shear(subject, region, hint),
      'resistance' => _resistance(subject, region, hint),
      'flow' => _flow(subject, region, hint),
      _ => 'Chronoflux variable on "$subject" in $region.',
    };
  }

  static String _vortex(String subject, String region, String hint) {
    if (hint.contains('electoral')) {
      return 'ω (vortex): Incumbent and party machines in $region compress "$subject" '
          'into turnout and mandate narratives ahead of establishment briefings.';
    }
    if (hint.contains('institutional')) {
      return 'ω (vortex): Senior officials and legacy outlets in $region steer "$subject" '
          'through procedural framing that privileges institutional credibility.';
    }
    return 'ω (vortex): Authority circulation in $region spins "$subject" via elite '
        'briefings and headline framing that set the official story arc.';
  }

  static String _shear(String subject, String region, String hint) {
    if (hint.contains('disorder') || hint.contains('collective')) {
      return 'σ (shear): Street-level and X discourse on "$subject" in $region shows '
          'grievance layers sharpening between security hawks and civil-liberty voices.';
    }
    if (hint.contains('narrative')) {
      return 'σ (shear): Polarized public threads on "$subject" split $region audiences '
          'between trust-the-lens and challenge-the-frame camps.';
    }
    return 'σ (shear): Open discussion on "$subject" in $region carries partisan shear — '
        'bottom-up anger and top-down dismissal coexisting in the same feed.';
  }

  static String _resistance(String subject, String region, String hint) {
    if (hint.contains('economic') || hint.contains('macro')) {
      return 'Iτ (resistance): Fiscal and regulatory guardrails in $region dampen rapid '
          'movement on "$subject" — institutions cite stability data to slow escalation.';
    }
    if (hint.contains('institutional')) {
      return 'Iτ (resistance): Courts, regulators, and civil-service inertia in $region '
          'push back on rapid change around "$subject".';
    }
    return 'Iτ (resistance): Institutional pushback on "$subject" in $region — official '
        'denials, procedural delay, and compliance checks absorb activist pressure.';
  }

  static String _flow(String subject, String region, String hint) {
    if (hint.contains('narrative')) {
      return 'Jμ (flow): Trust transport on "$subject" in $region compresses nuance into '
          'shareable clips — detail thins as the story crosses platforms.';
    }
    if (hint.contains('probability')) {
      return 'Jμ (flow): Probability talk on "$subject" in $region shuttles between '
          'expert caveats and headline certainty, thinning middle-ground trust.';
    }
    return 'Jμ (flow): Public channels on "$subject" in $region move nuance unevenly — '
        'local testimony travels, but establishment statements dominate reach.';
  }

  static String _clamp(String text, int maxLen) {
    final t = text.trim();
    if (t.length <= maxLen) return t;
    final cut = t.substring(0, maxLen - 1).trimRight();
    final lastSpace = cut.lastIndexOf(' ');
    final body = lastSpace > maxLen ~/ 2 ? cut.substring(0, lastSpace) : cut;
    return '$body…';
  }
}