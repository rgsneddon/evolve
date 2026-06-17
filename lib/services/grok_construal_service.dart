import 'dart:convert';

import 'package:http/http.dart' as http;

import '../l10n/localized_output.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import 'grok_auth_client.dart';
import 'grok_field_sanitizer.dart';
import 'grok_heuristic_construal.dart';
import 'narrative_construct_construal.dart';

/// Applies live Grok suggestions to blank construct fields (never overwrites user bias).
class GrokConstrualService {
  const GrokConstrualService({
    this.baseUrl = 'http://127.0.0.1:8787',
    http.Client? client,
  }) : _client = client;

  final String baseUrl;
  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  Future<GrokConstrualResult> fetchSuggestions({
    required ScenarioInput input,
    required LocaleConfig locale,
    LocalizedOutput? output,
  }) async {
    final out = output ?? LocalizedOutput.of(locale);
    final body = jsonEncode(
      NarrativeConstructConstrual.grokPayload(input, locale, out),
    );

    final res = await _http
        .post(
          Uri.parse('$baseUrl/construe'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode == 401) {
      throw GrokAuthException('unauthorized', message: res.body);
    }
    if (res.statusCode != 200) {
      throw GrokAuthException('construe', message: res.body);
    }

    final raw = GrokConstrualResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
    final sanitized = GrokFieldSanitizer.sanitizeResult(
      raw: raw,
      input: input,
      locale: locale,
      output: out,
    );
    return _backfillBlankFields(
      input: input,
      partial: sanitized,
      locale: locale,
      out: out,
    );
  }

  /// After sanitization, refill any stripped-empty slots with lever-only discourse lines.
  GrokConstrualResult _backfillBlankFields({
    required ScenarioInput input,
    required GrokConstrualResult partial,
    required LocaleConfig locale,
    required LocalizedOutput out,
  }) {
    final fallback = NarrativeConstructConstrual.isNarrativeLinked(input)
        ? NarrativeConstructConstrual.suggest(
            input: input,
            locale: locale,
            output: out,
          )
        : GrokHeuristicConstrual.suggest(
            input: input,
            locale: locale,
            output: out,
          );

    String pick(String primary, String secondary) =>
        primary.trim().isNotEmpty ? primary.trim() : secondary.trim();

    return GrokConstrualResult(
      vortexText: pick(partial.vortexText, fallback.vortexText),
      shearText: pick(partial.shearText, fallback.shearText),
      resistanceText: pick(partial.resistanceText, fallback.resistanceText),
      flowText: pick(partial.flowText, fallback.flowText),
      provenance: partial.provenance,
    );
  }

  /// Merge suggestions into [input] — only fills empty construct text fields.
  ScenarioInput applySuggestions(
    ScenarioInput input,
    GrokConstrualResult suggestions,
  ) {
    if (!suggestions.hasSuggestions) return input;

    return input.copyWith(
      vortexText: input.vortexText.trim().isEmpty && suggestions.vortexText.isNotEmpty
          ? suggestions.vortexText
          : input.vortexText,
      shearText: input.shearText.trim().isEmpty && suggestions.shearText.isNotEmpty
          ? suggestions.shearText
          : input.shearText,
      resistanceText:
          input.resistanceText.trim().isEmpty && suggestions.resistanceText.isNotEmpty
              ? suggestions.resistanceText
              : input.resistanceText,
      flowText: input.flowText.trim().isEmpty && suggestions.flowText.isNotEmpty
          ? suggestions.flowText
          : input.flowText,
    );
  }
}