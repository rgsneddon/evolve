import 'grok_field_sanitizer.dart';
import 'question_parameter_scraper.dart';
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
      return _clamp(
        GrokFieldSanitizer.sanitizeField(obs, regionLabel: region),
        500,
      );
    }
    return _clamp(_line(construct, hintSignals), 500);
  }

  static String fromQuestion({
    required String construct,
    required String posedQuestion,
    required String regionId,
    String? regionLabel,
    String? observationalNarrative,
    String topic = '',
  }) {
    final obs = observationalNarrative?.trim() ?? '';
    if (obs.isNotEmpty && !obs.toLowerCase().startsWith('posed question:')) {
      return forConstruct(
        construct: construct,
        subject: '',
        region: regionLabel ?? RegionContext.englishLabel(regionId),
        hintSignals: const [],
        observationalNarrative: obs,
      );
    }

    final sem = QuestionSemantics.fromText(
      posedQuestion,
      regionId: regionId,
      regionLabel: regionLabel,
    );
    final scraped = QuestionParameterScraper.scrape(
      question: posedQuestion,
      topic: topic,
      sem: sem,
    );
    return _clamp(scraped[construct]?.trim() ?? '', 500);
  }

  static String _line(String construct, List<String> hints) {
    final hint = hints.isNotEmpty ? hints.join(' ').toLowerCase() : '';
    return switch (construct) {
      'vortex' => _vortex(hint),
      'shear' => _shear(hint),
      'resistance' => _resistance(hint),
      'flow' => _flow(hint),
      _ => 'Chronoflux lever channel active.',
    };
  }

  static String _vortex(String hint) {
    if (hint.contains('electoral')) {
      return 'ω (vortex): Incumbent and party machines compress turnout '
          'and mandate levers through establishment briefings and headline framing.';
    }
    if (hint.contains('institutional')) {
      return 'ω (vortex): Senior officials and legacy outlets steer '
          'procedural framing levers that privilege institutional credibility.';
    }
    return 'ω (vortex): Authority-circulation levers — elite briefings, '
        'spokesperson lanes, and official story arcs set the ω compression field.';
  }

  static String _shear(String hint) {
    if (hint.contains('disorder') || hint.contains('collective')) {
      return 'σ (shear): Street-level and X discourse levers sharpen '
          'grievance layers between security hawks and civil-liberty voices.';
    }
    if (hint.contains('narrative')) {
      return 'σ (shear): Polarized public-thread levers split audiences '
          'between trust-the-lens and challenge-the-frame camps.';
    }
    return 'σ (shear): Partisan shear levers — bottom-up anger and '
        'top-down dismissal coexisting across open discussion channels.';
  }

  static String _resistance(String hint) {
    if (hint.contains('economic') || hint.contains('macro')) {
      return 'Iτ (resistance): Fiscal and regulatory guardrail levers '
          'dampen rapid movement — stability data cited to slow escalation.';
    }
    if (hint.contains('institutional')) {
      return 'Iτ (resistance): Courts, regulators, and civil-service inertia levers '
          'push back on rapid institutional change.';
    }
    return 'Iτ (resistance): Drag levers — official denials, procedural '
        'delay, and compliance checks absorb activist pressure.';
  }

  static String _flow(String hint) {
    if (hint.contains('narrative')) {
      return 'Jμ (flow): Trust-transport levers compress nuance into '
          'shareable clips — detail thins as stories cross platforms.';
    }
    if (hint.contains('probability')) {
      return 'Jμ (flow): Probability-talk levers shuttle between expert caveats '
          'and headline certainty, thinning middle-ground trust.';
    }
    return 'Jμ (flow): Channel-reach levers move nuance unevenly — '
        'local testimony travels while establishment statements dominate broadcast reach.';
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