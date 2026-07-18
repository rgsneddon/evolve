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

  /// When set, answers whether a platform installer URL is reachable (HEAD/GET).
  @visibleForTesting
  static Future<bool> Function(Uri url)? headProbeOverride;

  Future<AppUpdateInfo> check({
    String current = PercAppVersion.current,
  }) async {
    // gh-pages is the published release feed (installers + web). main/version.json
    // may run ahead from the pre-push hook before a full publish — do not treat
    // it as newer than Pages when both are reachable.
    RemoteVersionFeed? published;
    var anySucceeded = false;
    var fromPages = false;

    final pagesFeed = await _fetchFeed(Uri.parse(pagesVersionUrl));
    if (pagesFeed != null && pagesFeed.release.isNotEmpty) {
      published = pagesFeed;
      fromPages = true;
      anySucceeded = true;
    } else {
      final mainFeed = await _fetchFeed(Uri.parse(sourceVersionUrl));
      if (mainFeed != null && mainFeed.release.isNotEmpty) {
        published = mainFeed;
        anySucceeded = true;
      }
    }

    if (!anySucceeded || published == null || published.release.isEmpty) {
      return AppUpdateInfo(
        currentFull: current,
        latestFull: current,
        updateAvailable: false,
        checkSucceeded: false,
        updateUrl: downloadsBaseUrl,
      );
    }

    if (PercAppVersion.compare(current, published.full) >= 0) {
      return AppUpdateInfo(
        currentFull: current,
        latestFull: current,
        updateAvailable: false,
        checkSucceeded: true,
        updateUrl: updateUrlForRelease(published.release),
      );
    }

    final installedUpToDate =
        PercAppVersion.compare(current, published.full) >= 0;
    final semverNewer = PercAppVersion.isNewerThan(published.full, current);
    final releaseLineNewer = PercAppVersion.releaseOf(published.full) !=
        PercAppVersion.releaseOf(current);
    var updateAvailable = false;
    if (!installedUpToDate && semverNewer) {
      // main/version.json may run ahead via pre-push hook on the same release
      // line (e.g. 4.0.4+150) while gh-pages and Releases still ship +149.
      // Only gh-pages may advertise build-only bumps; main needs a new semver.
      final mayAdvertise = fromPages || releaseLineNewer;
      if (mayAdvertise) {
        final installerReady =
            await _installerPublished(published.release);
        updateAvailable = installerReady;
      }
    }

    final latestFull = installedUpToDate ? current : published.full;

    return AppUpdateInfo(
      currentFull: current,
      latestFull: latestFull,
      updateAvailable: updateAvailable,
      checkSucceeded: true,
      updateUrl: updateUrlForRelease(published.release),
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
      case TargetPlatform.iOS:
        return [
          '$releasesBaseUrl/$tag/evolve-v$release-ios-setup.ipa',
          '$downloadsBaseUrl$tag/evolve-v$release-ios-setup.ipa',
          'https://github.com/rgsneddon/evolve/releases/tag/$tag',
          '$downloadsBaseUrl$tag/',
        ];
      case TargetPlatform.macOS:
        return [
          '$releasesBaseUrl/$tag/evolve-v$release-macos-x64.zip',
          '$downloadsBaseUrl$tag/evolve-v$release-macos-x64.zip',
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
      final sanitized = body.startsWith('\uFEFF') ? body.substring(1) : body;
      final json = jsonDecode(sanitized) as Map<String, dynamic>;
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

  Future<bool> _installerPublished(String release) async {
    if (kIsWeb) {
      return _headOk(Uri.parse('https://rgsneddon.github.io/evolve/'));
    }
    for (final url in updateUrlsForRelease(release)) {
      final uri = Uri.parse(url);
      if (!_looksLikeInstallerUrl(uri)) continue;
      if (await _headOk(uri)) return true;
    }
    return false;
  }

  bool _looksLikeInstallerUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.apk') ||
        path.endsWith('.exe') ||
        path.endsWith('.ipa') ||
        path.endsWith('.zip') ||
        uri.host == 'github.com' && path.contains('/releases/download/');
  }

  Future<bool> _headOk(Uri uri) async {
    if (headProbeOverride != null) {
      return headProbeOverride!(uri);
    }
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .head(uri)
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}