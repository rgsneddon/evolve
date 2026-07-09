import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_app_version.dart';

/// Highest `build` in installer/android/evolve-v*-android.json manifests.
int maxPublishedAndroidBuild(String repoRoot) {
  final dir = Directory('$repoRoot/installer/android');
  if (!dir.existsSync()) return 0;
  var max = 0;
  for (final file in dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'evolve-v.+-android\.json$').hasMatch(f.path))) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final build = int.tryParse('${json['build']}') ?? 0;
    if (build > max) max = build;
  }
  return max;
}

void main() {
  final repoRoot = Directory.current.path;

  test('current Android build exceeds max published installer manifest', () {
    final maxPublished = maxPublishedAndroidBuild(repoRoot);
    expect(maxPublished, greaterThanOrEqualTo(136));
    final currentBuild = PercAppVersion.buildOf(PercAppVersion.current);
    expect(
      currentBuild,
      greaterThan(maxPublished),
      reason:
          'versionCode $currentBuild must exceed published Android build $maxPublished',
    );
  });

  test('broken v4.0.4+3 build is below published Android versionCode ceiling', () {
    final maxPublished = maxPublishedAndroidBuild(repoRoot);
    expect(PercAppVersion.buildOf('4.0.4+3'), lessThan(maxPublished));
    expect(PercAppVersion.buildOf(PercAppVersion.current), greaterThan(maxPublished));
  });
}