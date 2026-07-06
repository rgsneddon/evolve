import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../perc/perc_app_version.dart';

/// Result of comparing the installed app against published version feeds.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentFull,
    required this.latestFull,
    required this.updateAvailable,
    required this.checkSucceeded,
    required this.updateUrl,
  });

  final String currentFull;
  final String latestFull;
  final bool updateAvailable;
  final bool checkSucceeded;
  final String updateUrl;

  String get currentRelease => PercAppVersion.releaseOf(currentFull);
  String get latestRelease => PercAppVersion.releaseOf(latestFull);
  int get currentBuild => PercAppVersion.buildOf(currentFull);
  int get latestBuild => PercAppVersion.buildOf(latestFull);

  String get currentLabel => 'v$currentRelease (build $currentBuild)';
  String get latestLabel => 'v$latestRelease (build $latestBuild)';
}

class RemoteVersionFeed {
  const RemoteVersionFeed({required this.release, required this.build});

  final String release;
  final int build;

  String get full => '$release+$build';

  factory RemoteVersionFeed.fromJson(Map<String, dynamic> json) {
    final release = (json['version'] as String? ?? '').trim();
    final buildRaw = json['build_number'];
    final build = buildRaw is int
        ? buildRaw
        : int.tryParse('$buildRaw') ?? 0;
    return RemoteVersionFeed(release: release, build: build);
  }
}

/// Checks GitHub Pages and main-branch version.json for a newer published build.
class AppUpdateChecker {
  const AppUpdateChecker({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const pagesVersionUrl =
      'https://rgsneddon.github.io/evolve/version.json';
  static const sourceVersionUrl =
      'https://raw.githubusercontent.com/rgsneddon/evolve/main/version.json';
  static const downloadsBaseUrl =
      'https://rgsneddon.github.io/evolve/downloads/';
  static const releasesBaseUrl =
      'https://github.com/rgsneddon/evolve/releases/download';

  @visibleForTesting
  static Future<String?> Function(Uri url)? fetchBodyOverride;

  Future<AppUpdateInfo> check({
    String current = PercAppVersion.current,
  }) async {
    RemoteVersionFeed? newest;
    var anySucceeded = false;

    for (final url in [pagesVersionUrl, sourceVersionUrl]) {
      final feed = await _fetchFeed(Uri.parse(url));
      if (feed == null) continue;
      anySucceeded = true;
      if (newest == null ||
          PercAppVersion.compare(feed.full, newest.full) > 0) {
        newest = feed;
      }
    }

    if (!anySucceeded || newest == null || newest.release.isEmpty) {
      return AppUpdateInfo(
        currentFull: current,
        latestFull: current,
        updateAvailable: false,
        checkSucceeded: false,
        updateUrl: downloadsBaseUrl,
      );
    }

    final updateAvailable = PercAppVersion.isNewerThan(newest.full, current);
    return AppUpdateInfo(
      currentFull: current,
      latestFull: newest.full,
      updateAvailable: updateAvailable,
      checkSucceeded: true,
      updateUrl: updateUrlForRelease(newest.release),
    );
  }

  static String updateUrlForRelease(String release) {
    return updateUrlsForRelease(release).first;
  }

  /// Ordered download candidates — first reachable link wins in the UI.
  static List<String> updateUrlsForRelease(String release) {
    if (kIsWeb) {
      return const ['https://rgsneddon.github.io/evolve/'];
    }
    final tag = 'v$release';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return [
          '$releasesBaseUrl/$tag/evolve-v$release-android-setup.apk',
          '$downloadsBaseUrl$tag/evolve-v$release-android-setup.apk',
          'https://github.com/rgsneddon/evolve/releases/tag/$tag',
          '$downloadsBaseUrl$tag/',
        ];
      case TargetPlatform.windows:
        return [
          '$releasesBaseUrl/$tag/evolve-v$release-windows-x64-setup.exe',
          '$downloadsBaseUrl$tag/evolve-v$release-windows-x64-setup.exe',
          'https://github.com/rgsneddon/evolve/releases/tag/$tag',
          '$downloadsBaseUrl$tag/',
        ];
      default:
        return [downloadsBaseUrl];
    }
  }

  Future<RemoteVersionFeed?> _fetchFeed(Uri uri) async {
    try {
      final body = fetchBodyOverride != null
          ? await fetchBodyOverride!(uri)
          : await _fetchBody(uri);
      if (body == null || body.trim().isEmpty) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      return RemoteVersionFeed.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchBody(Uri uri) async {
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return response.body;
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}