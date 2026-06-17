import 'question_semantics.dart';
import 'region_context.dart';

/// Offline discourse-style construct lines — lever-only per ω/σ/Iτ/Jμ, no question echo.
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
      return _clamp(_stripQuotedParameters(obs), 500);
    }
    return _clamp(_line(construct, region, hintSignals), 500);
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
    String region,
    List<String> hints,
  ) {
    final hint = hints.isNotEmpty ? hints.first.toLowerCase() : '';
    return switch (construct) {
      'vortex' => _vortex(region, hint),
      'shear' => _shear(region, hint),
      'resistance' => _resistance(region, hint),
      'flow' => _flow(region, hint),
      _ => 'Chronoflux lever channel in $region.',
    };
  }

  static String _vortex(String region, String hint) {
    if (hint.contains('electoral')) {
      return 'ω (vortex): Incumbent and party machines in $region compress turnout '
          'and mandate levers through establishment briefings and headline framing.';
    }
    if (hint.contains('institutional')) {
      return 'ω (vortex): Senior officials and legacy outlets in $region steer '
          'procedural framing levers that privilege institutional credibility.';
    }
    return 'ω (vortex): Authority-circulation levers in $region — elite briefings, '
        'spokesperson lanes, and official story arcs set the ω compression field.';
  }

  static String _shear(String region, String hint) {
    if (hint.contains('disorder') || hint.contains('collective')) {
      return 'σ (shear): Street-level and X discourse levers in $region sharpen '
          'grievance layers between security hawks and civil-liberty voices.';
    }
    if (hint.contains('narrative')) {
      return 'σ (shear): Polarized public-thread levers split $region audiences '
          'between trust-the-lens and challenge-the-frame camps.';
    }
    return 'σ (shear): Partisan shear levers in $region — bottom-up anger and '
        'top-down dismissal coexisting across open discussion channels.';
  }

  static String _resistance(String region, String hint) {
    if (hint.contains('economic') || hint.contains('macro')) {
      return 'Iτ (resistance): Fiscal and regulatory guardrail levers in $region '
          'dampen rapid movement — stability data cited to slow escalation.';
    }
    if (hint.contains('institutional')) {
      return 'Iτ (resistance): Courts, regulators, and civil-service inertia levers '
          'in $region push back on rapid institutional change.';
    }
    return 'Iτ (resistance): Drag levers in $region — official denials, procedural '
        'delay, and compliance checks absorb activist pressure.';
  }

  static String _flow(String region, String hint) {
    if (hint.contains('narrative')) {
      return 'Jμ (flow): Trust-transport levers in $region compress nuance into '
          'shareable clips — detail thins as stories cross platforms.';
    }
    if (hint.contains('probability')) {
      return 'Jμ (flow): Probability-talk levers shuttle between expert caveats '
          'and headline certainty, thinning middle-ground trust in $region.';
    }
    return 'Jμ (flow): Channel-reach levers in $region move nuance unevenly — '
        'local testimony travels while establishment statements dominate broadcast reach.';
  }

  /// Removes quoted question/subject parameters Grok may echo into fields.
  static String stripQuotedParameters(String text) => _stripQuotedParameters(text);

  static String _stripQuotedParameters(String text) {
    var t = text.trim();
    if (t.isEmpty) return t;
    t = t.replaceAll(RegExp(r'[""][^""]+[""]'), '');
    t = t.replaceAll(RegExp(r'«[^»]+»'), '');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
    t = t.replaceAll(RegExp(r'\s+([,.;:])'), r'$1');
    return t.trim();
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