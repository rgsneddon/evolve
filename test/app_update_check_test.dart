import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/app_update_check.dart';

void main() {
  tearDown(() {
    AppUpdateChecker.fetchBodyOverride = null;
  });

  test('reports update when remote build is newer', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.toString().contains('version.json')) {
        return '{"version":"3.3.12","build_number":"10","app_name":"evolve"}';
      }
      return null;
    };

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

  test('falls back to main when gh-pages is unreachable', () async {
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return null;
      }
      return '{"version":"3.3.11","build_number":"95","app_name":"evolve"}';
    };

    final info = await const AppUpdateChecker().check(current: '3.3.11+89');
    expect(info.latestFull, '3.3.11+95');
    expect(info.updateAvailable, isTrue);
  });

  test('check fails gracefully when feeds are unreachable', () async {
    AppUpdateChecker.fetchBodyOverride = (_) async => null;

    final info = await const AppUpdateChecker().check(current: '3.3.11+89');
    expect(info.checkSucceeded, isFalse);
    expect(info.updateAvailable, isFalse);
  });
}