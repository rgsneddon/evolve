import '../l10n/localized_output.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'grok_proxy/grok_construct_prompt.dart';
import 'question_semantics.dart';

/// Normalizes Grok-construe field text — lever-only, no quoted question/subject parameters.
class GrokFieldSanitizer {
  const GrokFieldSanitizer._();

  static const _maxLen = 400;

  static GrokConstrualResult sanitizeResult({
    required GrokConstrualResult raw,
    required ScenarioInput input,
    required LocaleConfig locale,
    LocalizedOutput? output,
  }) {
    final out = output ?? LocalizedOutput.of(locale);
    final question = input.posedQuestion.trim();
    if (question.isEmpty) return raw;

    final region = out.regionName(locale.regionId);
    final sem = QuestionSemantics.parse(
      input,
      regionId: locale.regionId,
      regionLabel: region,
    );

    return GrokConstrualResult(
      vortexText: sanitizeField(
        raw.vortexText,
        posedQuestion: question,
        displaySubject: sem.displaySubject,
        rawSubject: sem.subject,
        regionLabel: region,
      ),
      shearText: sanitizeField(
        raw.shearText,
        posedQuestion: question,
        displaySubject: sem.displaySubject,
        rawSubject: sem.subject,
        regionLabel: region,
      ),
      resistanceText: sanitizeField(
        raw.resistanceText,
        posedQuestion: question,
        displaySubject: sem.displaySubject,
        rawSubject: sem.subject,
        regionLabel: region,
      ),
      flowText: sanitizeField(
        raw.flowText,
        posedQuestion: question,
        displaySubject: sem.displaySubject,
        rawSubject: sem.subject,
        regionLabel: region,
      ),
      provenance: raw.provenance,
    );
  }

  static Map<String, String> sanitizeFieldMap(
    Map<String, dynamic> parsed,
    String posedQuestion, {
    String displaySubject = '',
    String rawSubject = '',
    String regionLabel = '',
  }) {
    final question = posedQuestion.trim();
    String clean(String key, String construct) {
      final raw = '${parsed[key] ?? ''}'.trim();
      if (raw.isEmpty) return '';
      var stripped = sanitizeField(
        raw,
        posedQuestion: question,
        displaySubject: displaySubject,
        rawSubject: rawSubject,
        regionLabel: regionLabel,
      );
      if (stripped.isEmpty) return '';
      if (question.isNotEmpty && GrokConstructPrompt.isQuestionEcho(stripped, question)) {
        return '';
      }
      return _clamp(stripped, _maxLen);
    }

    return {
      'vortexText': clean('vortexText', 'vortex'),
      'shearText': clean('shearText', 'shear'),
      'resistanceText': clean('resistanceText', 'resistance'),
      'flowText': clean('flowText', 'flow'),
    };
  }

  static String sanitizeField(
    String field, {
    String posedQuestion = '',
    String displaySubject = '',
    String rawSubject = '',
    String regionLabel = '',
  }) {
    var t = field.trim();
    if (t.isEmpty) return t;

    t = t.replaceFirst(RegExp(r'^posed question:\s*', caseSensitive: false), '');
    t = _stripQuotedSpans(t);
    t = _stripSubjectEcho(t, displaySubject);
    t = _stripSubjectEcho(t, rawSubject);
    if (posedQuestion.trim().isNotEmpty) {
      t = _stripSubjectEcho(t, posedQuestion.trim());
    }
    t = _stripRegionEcho(t, regionLabel);
    t = _tidyPunctuation(t);
    return t.trim();
  }

  static String _stripRegionEcho(String text, String regionLabel) {
    final region = regionLabel.trim();
    if (region.isEmpty) return text;
    var t = text;
    final escaped = RegExp.escape(region);
    t = t.replaceAll(
      RegExp('\\bin\\s+$escaped\\b', caseSensitive: false),
      '',
    );
    t = t.replaceAll(
      RegExp('$escaped\\s+audiences', caseSensitive: false),
      'audiences',
    );
    t = t.replaceAll(
      RegExp('\\b$escaped\\b', caseSensitive: false),
      '',
    );
    return t;
  }

  static String _stripQuotedSpans(String text) {
    var t = text;
    final patterns = [
      RegExp(r'"(?:[^"\\]|\\.)*"'),
      RegExp(r"'(?:[^'\\]|\\.)*'"),
      RegExp(r'[\u201C][^\u201D]*[\u201D]'),
      RegExp(r'[\u2018][^\u2019]*[\u2019]'),
      RegExp(r'«[^»]*»'),
    ];
    for (final pattern in patterns) {
      t = t.replaceAll(pattern, '');
    }
    t = t.replaceAll(RegExp(r'[\u201C\u201D\u2018\u2019]{1,2}'), '');
    return t;
  }

  static String _stripSubjectEcho(String text, String subject) {
    final s = subject.trim();
    if (s.length < 4) return text;
    var t = text;
    t = t.replaceAll(RegExp(RegExp.escape(s), caseSensitive: false), '');
    return t;
  }

  static String _tidyPunctuation(String text) {
    var t = text;
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
    t = t.replaceAll(RegExp(r'\s+([,.;:])'), r'$1');
    t = t.replaceAll(
      RegExp(r'\b(?:on|for|about|regarding|around|relative to)\s*(?=[,.;:]|\s*$)', caseSensitive: false),
      '',
    );
    t = t.replaceAll(RegExp(r'\(\s*\)'), '');
    t = t.replaceAll(RegExp(r'\s+—\s+—'), ' — ');
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