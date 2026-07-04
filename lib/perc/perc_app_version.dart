/// App release version — keep in sync with pubspec.yaml `version:`.
class PercAppVersion {
  const PercAppVersion._();

  static const String current = '3.1.2+68';

  /// Semver label without `+build` (e.g. `1.2.0+34` → `1.2.0`).
  static String releaseOf(String version) {
    final plus = version.indexOf('+');
    return plus < 0 ? version.trim() : version.substring(0, plus).trim();
  }

  static int buildOf(String version) {
    final plus = version.indexOf('+');
    if (plus < 0) return 0;
    return int.tryParse(version.substring(plus + 1).trim()) ?? 0;
  }

  static List<int> _semverParts(String version) {
    return releaseOf(version)
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  /// Negative if [a] < [b], zero if equal release+build, positive if [a] > [b].
  static int compare(String a, String b) {
    final ap = _semverParts(a);
    final bp = _semverParts(b);
    for (var i = 0; i < 3; i++) {
      final av = i < ap.length ? ap[i] : 0;
      final bv = i < bp.length ? bp[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return buildOf(a).compareTo(buildOf(b));
  }

  static bool isNewerThan(String candidate, String baseline) =>
      compare(candidate, baseline) > 0;

  static bool sameReleaseLine(String a, String b) =>
      releaseOf(a) == releaseOf(b);
}