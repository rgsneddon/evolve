import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_app_version.dart';

/// Highest `build` in installer/android manifests, optionally excluding one release.
int maxPublishedAndroidBuild(
  String repoRoot, {
  String? excludeReleaseVersion,
}) {
  final dir = Directory('$repoRoot/installer/android');
  if (!dir.existsSync()) return 0;
  var max = 0;
  for (final file in dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'evolve-v.+-android\.json$').hasMatch(f.path))) {
    if (excludeReleaseVersion != null &&
        file.path.endsWith('evolve-v$excludeReleaseVersion-android.json')) {
      continue;
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final build = int.tryParse('${json['build']}') ?? 0;
    if (build > max) max = build;
  }
  return max;
}

void main() {
  final repoRoot = Directory.current.path;

  test('current Android build exceeds prior published installer manifests', () {
    final release = PercAppVersion.releaseOf(PercAppVersion.current);
    final maxPrior = maxPublishedAndroidBuild(
      repoRoot,
      excludeReleaseVersion: release,
    );
    expect(maxPrior, greaterThanOrEqualTo(148));
    final currentBuild = PercAppVersion.buildOf(PercAppVersion.current);
    expect(
      currentBuild,
      greaterThan(maxPrior),
      reason:
          'versionCode $currentBuild must exceed prior Android build $maxPrior',
    );
  });

  test('broken v4.0.4+3 build is below prior published Android versionCode', () {
    final maxPrior = maxPublishedAndroidBuild(
      repoRoot,
      excludeReleaseVersion: '4.0.4',
    );
    expect(PercAppVersion.buildOf('4.0.4+3'), lessThan(maxPrior));
    expect(
      PercAppVersion.buildOf(PercAppVersion.current),
      greaterThan(maxPrior),
    );
  });
}