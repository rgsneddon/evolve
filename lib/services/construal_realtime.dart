/// Shared real-time observance framing for Grok construal (ω/σ/Iτ/Jμ/ρt).
class ConstrualRealtime {
  const ConstrualRealtime._();

  static String analysisDateIso([DateTime? when]) {
    final d = when ?? DateTime.now().toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static const observationMandate =
      'Each field must be a real-time analysis — observed live social discourse, '
      'ongoing events, and pertinent data as of the analysis date, scoped ONLY to '
      'the posed scenario question. No generic templates, stale examples, or '
      'off-topic regions.';

  static String lead(String analysisDate) =>
      'Observed live as of $analysisDate —';

  static String withLead(String analysisDate, String body) {
    final t = body.trim();
    if (t.isEmpty) return t;
    if (_alreadyRealtime(t)) return t;
    return '${lead(analysisDate)} $t';
  }

  static bool _alreadyRealtime(String text) =>
      text.toLowerCase().contains('observed live as of');
}