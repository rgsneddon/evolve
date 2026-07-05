import '../../services/region_context.dart';

/// Ward moderator accounts — username prefix MOD_<geographical region>.
class FcgModerator {
  static const prefix = 'MOD_';

  static bool isModeratorUsername(String? username) {
    if (username == null || username.trim().isEmpty) return false;
    return username.trim().toUpperCase().startsWith(prefix);
  }

  /// Suggested moderator username for the current ward region.
  static String usernameForRegion(String regionId) {
    final label = RegionContext.englishLabel(regionId);
    final slug = label
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '$prefix${slug.isEmpty ? 'Global' : slug}';
  }

  static String regionLabel(String regionId) =>
      RegionContext.englishLabel(regionId);
}