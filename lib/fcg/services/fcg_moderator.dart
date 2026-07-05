import '../data/fcg_uk_ward_moderator_registry.dart';
import '../../services/region_context.dart';

/// Ward moderator accounts — whitelisted MOD_* usernames per UK electoral ward.
class FcgModerator {
  static const prefix = 'MOD_';

  /// Only ONS May 2025 UK ward moderator usernames (generated locally) are MODs.
  static bool isModeratorUsername(String? username) =>
      FcgUkWardModeratorRegistry.contains(username);

  /// Display label for a signed-in moderator, when known in the ward registry.
  static String? moderatorWardLabel(String? username) {
    if (username == null) return null;
    return FcgUkWardModeratorRegistry.wardNameFor(username);
  }

  /// Suggested moderator username for the current ward region (interim fallback).
  static String usernameForRegion(String regionId) {
    final label = RegionContext.englishLabel(regionId);
    final slug = label
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final base = slug.isEmpty ? 'global' : slug.toLowerCase();
    final candidate = 'mod_$base';
    if (FcgUkWardModeratorRegistry.contains(candidate)) return candidate;
    if (candidate.length <= 24) return candidate;
    return candidate.substring(0, 24);
  }

  static String regionLabel(String regionId) =>
      RegionContext.englishLabel(regionId);
}