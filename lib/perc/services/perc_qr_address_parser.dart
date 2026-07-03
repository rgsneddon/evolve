import 'perc_auth.dart';
import 'perc_beam_privacy.dart';

/// Extracts a PERC wallet address from QR/barcode payload text.
class PercQrAddressParser {
  const PercQrAddressParser._();

  static String? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = _validAddress(trimmed);
    if (direct != null) return direct;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.hasScheme || uri.hasQuery)) {
      for (final part in <String?>[
        uri.path,
        uri.fragment,
        uri.queryParameters['address'],
        uri.queryParameters['to'],
      ]) {
        final value = part?.trim() ?? '';
        if (value.isEmpty) continue;
        final fromUri = _validAddress(value);
        if (fromUri != null) return fromUri;
      }
    }

    for (final prefix in [
      PercBeamPrivacy.confidentialPrefix,
      'perc1',
    ]) {
      final idx = trimmed.indexOf(prefix);
      if (idx < 0) continue;
      final candidate = _sliceAddress(trimmed, idx, prefix);
      if (candidate != null) return candidate;
    }

    return null;
  }

  static String? _validAddress(String value) {
    final normalized = PercAuth.normalizeAddress(value);
    if (PercAuth.validateAddress(normalized) == null) return normalized;
    return null;
  }

  static String? _sliceAddress(String text, int start, String prefix) {
    final length = prefix == PercBeamPrivacy.confidentialPrefix ? 49 : 45;
    if (start + length > text.length) return null;
    return _validAddress(text.substring(start, start + length));
  }
}