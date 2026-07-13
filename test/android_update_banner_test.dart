import 'package:evolve/perc/perc_app_version.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/screens/evolve_loading_screen.dart';
import 'package:evolve/services/app_update_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'test_locale_provider.dart';

bool _installerUrl(Uri uri) =>
    uri.host.contains('github.com') &&
    uri.path.contains('/releases/download/');

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    EvolveLoadingScreen.introDurationOverride = null;
    AppUpdateChecker.fetchBodyOverride = null;
    AppUpdateChecker.headProbeOverride = null;
    PercLedgerHub.resetForTest();
  });

  test('AppUpdateChecker reports up to date when installed matches gh-pages',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final current = PercAppVersion.current;
    final release = PercAppVersion.releaseOf(current);
    final build = PercAppVersion.buildOf(current);
    AppUpdateChecker.fetchBodyOverride = (uri) async {
      if (uri.host.contains('github.io')) {
        return '{"version":"$release","build_number":"$build","app_name":"evolve"}';
      }
      return '{"version":"$release","build_number":"${build + 1}","app_name":"evolve"}';
    };
    AppUpdateChecker.headProbeOverride =
        (uri) async => _installerUrl(uri);

    final info = await const AppUpdateChecker().check(current: current);
    expect(info.checkSucceeded, isTrue);
    expect(info.updateAvailable, isFalse);
    expect(info.latestFull, current);
  });

  testWidgets(
    'EvolveLoadingScreen SplashVersionStatus hides update when feed matches',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final current = PercAppVersion.current;
      final release = PercAppVersion.releaseOf(current);
      final build = PercAppVersion.buildOf(current);
      AppUpdateChecker.fetchBodyOverride = (uri) async {
        if (uri.host.contains('github.io')) {
          return '{"version":"$release","build_number":"$build","app_name":"evolve"}';
        }
        return '{"version":"$release","build_number":"${build + 1}","app_name":"evolve"}';
      };
      AppUpdateChecker.headProbeOverride =
          (uri) async => uri.path.toLowerCase().endsWith('.apk');

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      final locale = await createTestLocaleProvider();
      final evolve = EvolveProvider();
      await evolve.initialize();
      EvolveLoadingScreen.introDurationOverride = Duration.zero;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wallet),
            ChangeNotifierProvider.value(value: locale),
            ChangeNotifierProvider.value(value: evolve),
          ],
          child: MaterialApp(
            home: EvolveLoadingScreen(
              walletReady: true,
              onAuthenticated: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Update available'), findsNothing);
      expect(find.textContaining('latest version'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    },
  );
}