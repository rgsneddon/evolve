import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/app_update_check.dart';

bool _installerUrl(Uri uri) =>
    uri.host.contains('github.com') &&
    uri.path.contains('/releases/download/');

void main() {
  tearDown(() {
    AppUpdateChecker.fetchBodyOverride = null;
    AppUpdateChecker.headProbeOverride = null;
  });

  test('reports update when remote build is newer and installer is published',
      () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.toString().contains('version.json')) {
        return '{"version":"3.3.12","build_number":"10","app_name":"evolve"}';
      }
      return null;
    };
    AppUpdateChecker.headProbeOverride =
        (uri) async => _installerUrl(uri);

    final info = await const AppUpdateChecker().check(current: '3.3.11+89');
    expect(info.checkSucceeded, isTrue);
    expect(info.updateAvailable, isTrue);
    expect(info.latestFull, '3.3.12+10');
    expect(
      info.updateUrl,
      startsWith(
        'https://github.com/rgsneddon/evolve/releases/download/v3.3.12/',
      ),
    );
    expect(info.updateUrl, contains('evolve-v3.3.12-'));
    final fallbacks = AppUpdateChecker.updateUrlsForRelease('3.3.12');
    expect(fallbacks.length, greaterThanOrEqualTo(2));
    expect(fallbacks.first, info.updateUrl);
  });

  test('reports up to date when remote matches or is older', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      return '{"version":"3.3.11","build_number":"89","app_name":"evolve"}';
    };

    final info = await const AppUpdateChecker().check(current: '3.3.11+89');
    expect(info.checkSucceeded, isTrue);
    expect(info.updateAvailable, isFalse);
    expect(info.latestFull, '3.3.11+89');
  });

  test('prefers gh-pages over newer main when both succeed', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return '{"version":"3.4.6","build_number":"113","app_name":"evolve"}';
      }
      return '{"version":"3.4.6","build_number":"114","app_name":"evolve"}';
    };

    final info = await const AppUpdateChecker().check(current: '3.4.6+113');
    expect(info.latestFull, '3.4.6+113');
    expect(info.updateAvailable, isFalse);
  });

  test('main-ahead-of-pages does not advertise unreleased build', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return '{"version":"4.0.4","build_number":"149","app_name":"evolve"}';
      }
      return '{"version":"4.0.4","build_number":"150","app_name":"evolve"}';
    };
    AppUpdateChecker.headProbeOverride =
        (uri) async => _installerUrl(uri);

    final info = await const AppUpdateChecker().check(current: '4.0.4+149');
    expect(info.checkSucceeded, isTrue);
    expect(info.latestFull, '4.0.4+149');
    expect(info.updateAvailable, isFalse);
  });

  test('suppresses update when feed is newer but installer is missing', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      return '{"version":"4.0.5","build_number":"1","app_name":"evolve"}';
    };
    AppUpdateChecker.headProbeOverride = (_) async => false;

    final info = await const AppUpdateChecker().check(current: '4.0.4+149');
    expect(info.checkSucceeded, isTrue);
    expect(info.latestFull, '4.0.5+1');
    expect(info.updateAvailable, isFalse);
  });

  test('falls back to main for semver bump when gh-pages is unreachable',
      () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return null;
      }
      return '{"version":"3.3.12","build_number":"10","app_name":"evolve"}';
    };
    AppUpdateChecker.headProbeOverride =
        (uri) async => _installerUrl(uri);

    final info = await const AppUpdateChecker().check(current: '3.3.11+89');
    expect(info.latestFull, '3.3.12+10');
    expect(info.updateAvailable, isTrue);
  });

  test('main fallback ignores same-release build bump even if installer exists',
      () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return null;
      }
      return '{"version":"4.0.4","build_number":"150","app_name":"evolve"}';
    };
    AppUpdateChecker.headProbeOverride =
        (uri) async => _installerUrl(uri);

    final info = await const AppUpdateChecker().check(current: '4.0.4+149');
    expect(info.checkSucceeded, isTrue);
    expect(info.latestFull, '4.0.4+150');
    expect(info.updateAvailable, isFalse);
  });

  test('main fallback does not advertise build without published installer',
      () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return null;
      }
      return '{"version":"4.0.4","build_number":"150","app_name":"evolve"}';
    };
    AppUpdateChecker.headProbeOverride = (_) async => false;

    final info = await const AppUpdateChecker().check(current: '4.0.4+149');
    expect(info.checkSucceeded, isTrue);
    expect(info.latestFull, '4.0.4+150');
    expect(info.updateAvailable, isFalse);
  });

  test('check fails gracefully when feeds are unreachable', () async {
    AppUpdateChecker.fetchBodyOverride = (_) async => null;

    final info = await const AppUpdateChecker().check(current: '3.3.11+89');
    expect(info.checkSucceeded, isFalse);
    expect(info.updateAvailable, isFalse);
  });

  test('consecutive checks are stable under feed divergence', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return '{"version":"4.0.4","build_number":"149","app_name":"evolve"}';
      }
      return '{"version":"4.0.4","build_number":"150","app_name":"evolve"}';
    };
    AppUpdateChecker.headProbeOverride =
        (uri) async => _installerUrl(uri);

    const checker = AppUpdateChecker();
    final run1 = await checker.check(current: '4.0.4+149');
    final run2 = await checker.check(current: '4.0.4+149');
    expect(run1.updateAvailable, run2.updateAvailable);
    expect(run1.latestFull, run2.latestFull);
    expect(run1.updateAvailable, isFalse);

    final scratch = Platform.environment['SCRATCH'];
    if (scratch != null && scratch.isNotEmpty) {
      final dir = Directory(scratch);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      void write(String name, AppUpdateInfo info) {
        File('${dir.path}${Platform.pathSeparator}$name').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({
            'currentFull': info.currentFull,
            'latestFull': info.latestFull,
            'updateAvailable': info.updateAvailable,
            'checkSucceeded': info.checkSucceeded,
            'updateUrl': info.updateUrl,
          })}\n',
        );
      }
      write('update_check_run1.json', run1);
      write('update_check_run2.json', run2);
    }
  });
}