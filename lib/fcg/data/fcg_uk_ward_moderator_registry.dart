import 'fcg_uk_ward_moderator_list.dart';

/// UK electoral-ward moderator whitelist (ONS May 2025 when generated locally).
abstract final class FcgUkWardModeratorRegistry {
  static final Set<String> usernames = Set.unmodifiable(
    fcgUkWardModeratorUsernames,
  );

  static final Map<String, String> wardNames = Map.unmodifiable(
    fcgUkWardModeratorWardNames,
  );

  /// ONS May 2025 ward code (e.g. e05000932, s13002516).
  static final RegExp onsWardCodePattern = RegExp(r'^[ewns]\d{8}$');

  /// Scottish ONS codes lowercased begin with s1 (s1* in Moderator Pack).
  static final RegExp scottishOnsCodePattern = RegExp(r'^s1\d{7}$');

  static String normalize(String username) => username.trim().toLowerCase();

  /// Ward slug (`mod_*`) or ONS code (`e05000932`, `s13002516`, …).
  static bool isModeratorAlias(String? username) {
    if (username == null || username.trim().isEmpty) return false;
    final u = normalize(username);
    if (u.startsWith('mod_')) return true;
    if (onsWardCodePattern.hasMatch(u)) return true;
    return false;
  }

  static String? wardNameFor(String username) {
    final key = normalize(username);
    return wardNames[key];
  }

  static bool contains(String? username) {
    if (username == null || username.trim().isEmpty) return false;
    return usernames.contains(normalize(username));
  }
}