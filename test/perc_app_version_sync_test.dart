import 'dart:io';

import 'package:evolve/perc/perc_app_version.dart';
import 'package:evolve/services/app_update_check.dart';
import 'package:flutter_test/flutter_test.dart';

String _pubspecVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*([0-9.]+\+\d+)', multiLine: true)
      .firstMatch(pubspec);
  if (match == null) {
    fail('pubspec.yaml missing version: line');
  }
  return match.group(1)!;
}

void main() {
  test('PercAppVersion.current matches pubspec.yaml version', () {
    expect(PercAppVersion.current, _pubspecVersion());
  });

  test('AppUpdateChecker reports no update when remote matches current', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      return '''
{"version":"4.0.8","build_number":1,"package_name":"evolve"}
''';
    };
    addTearDown(() => AppUpdateChecker.fetchBodyOverride = null);

    final info = await const AppUpdateChecker().check(
      current: PercAppVersion.current,
    );

    expect(info.checkSucceeded, isTrue);
    expect(info.updateAvailable, isFalse);
    expect(info.currentFull, PercAppVersion.current);
    expect(info.latestFull, PercAppVersion.current);
  });
}