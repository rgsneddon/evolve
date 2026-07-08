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

  /// Resolves moderator login: `mod_*`, ONS code, or `MOD_<Ward Name>` label.
  static String? resolveLoginAlias(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final direct = normalize(trimmed);
    if (contains(direct)) return direct;

    if (trimmed.toUpperCase().startsWith('MOD_')) {
      final label = trimmed.substring(4).trim();
      for (final entry in wardNames.entries) {
        if (entry.value.toLowerCase() == label.toLowerCase()) {
          if (entry.key.startsWith('mod_')) return entry.key;
        }
      }
    }
    return null;
  }

  static String? onsCodeFor(String username) {
    final key = normalize(username);
    if (onsWardCodePattern.hasMatch(key)) return key;
    for (final entry in wardNames.entries) {
      if (entry.key == key && onsWardCodePattern.hasMatch(entry.key)) {
        return entry.key;
      }
    }
    for (final u in usernames) {
      if (u.startsWith('mod_') && wardNames[u] == wardNames[key]) {
        for (final alt in usernames) {
          if (onsWardCodePattern.hasMatch(alt) && wardNames[alt] == wardNames[u]) {
            return alt;
          }
        }
      }
    }
    return null;
  }
}