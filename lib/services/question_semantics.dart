import 'dart:convert';

import '../models/scenario_input.dart';
import 'region_context.dart';

enum QuestionFrame { probability, predictive, magnitude, descriptive }

enum OutcomePolarity { favourable, adverse, open }

/// Open-ended ω semantics — any user question or scenario, not a fixed topic list.
class QuestionSemantics {
  const QuestionSemantics({
    required this.raw,
    required this.subject,
    required this.displaySubject,
    required this.frame,
    required this.polarity,
    required this.isInterrogative,
    required this.fingerprint,
    required this.vortexOffset,
    required this.shearOffset,
    required this.resistanceOffset,
    required this.flowOffset,
    required this.hintSignals,
  });

  final String raw;
  final String subject;
  final String displaySubject;
  final QuestionFrame frame;
  final OutcomePolarity polarity;
  final bool isInterrogative;
  final double fingerprint;
  final double vortexOffset;
  final double shearOffset;
  final double resistanceOffset;
  final double flowOffset;
  final List<String> hintSignals;

  factory QuestionSemantics.parse(
    ScenarioInput input, {
    String regionId = 'global',
    String? regionLabel,
  }) {
    final raw = input.scenarioQuery;
    return QuestionSemantics.fromText(
      raw,
      regionId: regionId,
      regionLabel: regionLabel,
    );
  }

  factory QuestionSemantics.fromText(
    String raw, {
    String regionId = 'global',
    String? regionLabel,
  }) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    final region = RegionContext(regionId);
    final fp = _fingerprint(lower);
    final frame = _detectFrame(lower);
    final isInterrogative = _isInterrogative(lower);
    final subject = _extractSubject(trimmed, lower);
    final displaySubject = region.scopeSubject(
      _display(subject),
      regionLabel ?? RegionContext.englishLabel(regionId),
    );
    final polarity = _detectPolarity(lower, subject);
    var hints = _hintSignals(lower, region);

    final wordCount = subject.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final complexity = (wordCount.clamp(2, 24) - 4) * 0.35;

    var vortex = 52.0 + complexity;
    var shear = 52.0 + complexity * 0.6;
    var resistance = 50.0 + complexity * 0.4;
    var flow = 54.0 + complexity * 0.3;

    if (isInterrogative) vortex += 4;
    if (frame == QuestionFrame.probability) {
      vortex += 3;
      flow += 4;
    }
    if (frame == QuestionFrame.predictive) vortex += 2;
    if (frame == QuestionFrame.magnitude) flow += 5;
    if (_hasUrgency(lower)) {
      vortex += 2;
      shear += 2;
    }

    for (final hint in hints) {
      vortex += hint.vortex;
      shear += hint.shear;
      resistance += hint.resistance;
      flow += hint.flow;
    }

    if (!region.isGlobal) {
      final bias = region.constructBias();
      if (!region.textMatchesRegion(lower)) {
        vortex += bias.vortex;
        shear += bias.shear;
        resistance += bias.resistance;
        flow += bias.flow;
        hints.add(_Hint(
          label: 'regional-scope-$regionId',
          vortex: bias.vortex,
          shear: bias.shear,
          resistance: bias.resistance,
          flow: bias.flow,
        ));
      } else {
        vortex += bias.vortex * 0.5;
        hints.add(_Hint(label: 'regional-ω-anchor-$regionId', vortex: bias.vortex * 0.5));
      }
      if (region.hasForeignGeography(lower)) {
        shear += 1.5;
        hints.add(_Hint(label: 'foreign-geo-suppressed-$regionId', shear: 1.5));
      }
    }

    vortex += fp * 0.5;
    shear += fp * 0.35;
    resistance += fp * 0.3;
    flow += fp * 0.25;

    if (polarity == OutcomePolarity.adverse) {
      shear += 3;
      flow -= 2;
    } else if (polarity == OutcomePolarity.favourable) {
      flow += 2;
      resistance -= 1;
    }

    return QuestionSemantics(
      raw: trimmed,
      subject: subject,
      displaySubject: displaySubject,
      frame: frame,
      polarity: polarity,
      isInterrogative: isInterrogative,
      fingerprint: fp,
      vortexOffset: vortex,
      shearOffset: shear,
      resistanceOffset: resistance,
      flowOffset: flow,
      hintSignals: hints.map((h) => h.label).toList(),
    );
  }

  static double _fingerprint(String text) {
    if (text.isEmpty) return 0;
    final bytes = utf8.encode(text);
    var hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7fffffff;
    }
    return ((hash % 17) - 8).toDouble();
  }

  static QuestionFrame _detectFrame(String lower) {
    if (RegExp(r'\b(chance|probability|likelihood|how likely|odds)\b').hasMatch(lower)) {
      return QuestionFrame.probability;
    }
    if (RegExp(r'\b(how much|how many|what (percent|percentage|share|proportion|level))\b')
        .hasMatch(lower)) {
      return QuestionFrame.magnitude;
    }
    if (RegExp(r'^(will|would|could|can|should|is it likely|are we going to)\b')
        .hasMatch(lower)) {
      return QuestionFrame.predictive;
    }
    if (lower.contains('?')) return QuestionFrame.probability;
    return QuestionFrame.descriptive;
  }

  static bool _isInterrogative(String lower) =>
      lower.contains('?') ||
      RegExp(r'^(what|who|when|where|why|how|will|would|could|can|should|is|are|do|does|did)\b')
          .hasMatch(lower);

  static String _extractSubject(String raw, String lower) {
    var s = lower;
    final patterns = [
      RegExp(
        r"^(?:what is|what's|whats|calculate|estimate|compute|give me|tell me|please)?\s*"
        r'(?:the\s+)?(?:percent(?:age)?\s+)?(?:chance|probability|likelihood)\s+(?:of|that)\s+',
        caseSensitive: false,
      ),
      RegExp(
        r'^what (?:percent(?:age)?|proportion|share) (?:of )?(?:people |the population )?',
        caseSensitive: false,
      ),
      RegExp(r'^how likely is (?:it )?(?:that )?', caseSensitive: false),
      RegExp(r'^(?:will|would|could|can|should|is it likely that|are we going to)\s+', caseSensitive: false),
      RegExp(r'^(?:what|how much|how many)\s+(?:is|are|was|were)\s+(?:the\s+)?', caseSensitive: false),
      RegExp(r'^(?:do you think|please)\s+', caseSensitive: false),
    ];

    for (final p in patterns) {
      s = s.replaceFirst(p, '');
    }

    s = s.replaceAll(RegExp(r'\?\s*$'), '');
    s = s.replaceAll(RegExp(r'\b(?:please|near[- ]term|short[- ]term|long[- ]term)\b\.?$'), '');
    s = s.trim();

    if (s.length < 3) {
      s = lower.replaceAll('?', '').trim();
    }

    // Preserve original casing slice from raw where possible.
    if (s == lower && raw.isNotEmpty) {
      return raw.replaceAll(RegExp(r'\?\s*$'), '').trim();
    }

    final idx = lower.indexOf(s);
    if (idx >= 0 && idx < raw.length) {
      return raw.substring(idx, idx + s.length).trim();
    }
    return s;
  }

  static String _display(String subject) {
    final t = subject.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 88) return t;
    return '${t.substring(0, 85)}…';
  }

  static OutcomePolarity _detectPolarity(String lower, String subject) {
    final text = '$lower $subject'.toLowerCase();
    var adverse = 0;
    var favourable = 0;

    final adverseRx = RegExp(
      r'\b(unrest|riot|violence|war|conflict|invasion|attack|disorder|collapse|crisis|'
      r'recession|fail|threat|risk|danger|harm|lose|decline|fall|drop|worse|condemn|'
      r'backlash|resign|scandal|fraud|strike|shutdown|shortage|exceed|above|surge)\b',
    );
    final favourableRx = RegExp(
      r'\b(trust|cohesion|unity|peace|stable|stability|succeed|win|growth|improve|rise|'
      r'recover|hold|accept|believe|support|approve|recover|calm|resolve|agree)\b',
    );

    adverse = adverseRx.allMatches(text).length;
    favourable = favourableRx.allMatches(text).length;

    if (adverse > favourable + 1) return OutcomePolarity.adverse;
    if (favourable > adverse + 1) return OutcomePolarity.favourable;
    return OutcomePolarity.open;
  }

  static bool _hasUrgency(String lower) =>
      RegExp(r'\b(urgent|imminent|soon|near[- ]term|this year|this month|before|deadline|now)\b')
          .hasMatch(lower);

  static List<_Hint> _hintSignals(String lower, RegionContext region) {
    final hints = <_Hint>[];
    void add(String label, {double v = 0, double s = 0, double r = 0, double f = 0}) {
      hints.add(_Hint(label: label, vortex: v, shear: s, resistance: r, flow: f));
    }

    // Optional discourse hints — never required for a valid conclusion.
    if (RegExp(r'\b(unrest|protest|riot|disorder|march)\b').hasMatch(lower)) {
      add('collective-disorder circulation', v: 10, s: 12);
    }
    if (RegExp(r'\b(trust|narrative|lens|believe|accept)\b').hasMatch(lower)) {
      add('narrative-lens compression', v: 8, s: 6);
    }
    if (RegExp(r'\b(inflation|economy|recession|gdp|cost of living)\b').hasMatch(lower)) {
      add('macro-economic pressure', v: 5, r: 3);
    }
    if (RegExp(r'\b(election|vote|referendum|poll)\b').hasMatch(lower)) {
      add('electoral vortex', v: 7, s: 5);
    }
    if (RegExp(r'\b(government|minister|institution|policy|official)\b').hasMatch(lower)) {
      add('institutional framing', r: 6);
    }
    if (RegExp(r'\b(mayor|resign|cabinet|parliament|senator|governor)\b').hasMatch(lower)) {
      add('electoral vortex', v: 5, s: 4);
    }
    if (RegExp(r'\b(housing|health|transport|rail|energy|climate|asteroid|impact)\b')
        .hasMatch(lower)) {
      add('open-scenario pressure', v: 3, s: 3, f: 2);
    }
    if (!region.isGlobal && region.textMatchesRegion(lower)) {
      add('regional ω anchor (${region.regionId})', v: 2);
    }

    return hints;
  }
}

class _Hint {
  const _Hint({
    required this.label,
    this.vortex = 0,
    this.shear = 0,
    this.resistance = 0,
    this.flow = 0,
  });

  final String label;
  final double vortex;
  final double shear;
  final double resistance;
  final double flow;
}