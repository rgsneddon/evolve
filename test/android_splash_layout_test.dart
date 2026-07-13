import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/screens/evolve_loading_screen.dart';
import 'package:evolve/services/app_update_check.dart';
import 'package:evolve/widgets/evolve_splash_poster.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'test_locale_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    EvolveLoadingScreen.introDurationOverride = null;
    AppUpdateChecker.fetchBodyOverride = null;
    PercLedgerHub.resetForTest();
  });

  Future<void> pumpAndroidSplash(
    WidgetTester tester, {
    required Size viewport,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    final locale = await createTestLocaleProvider();
    final evolve = EvolveProvider();
    await evolve.initialize();
    EvolveLoadingScreen.introDurationOverride = Duration.zero;
    AppUpdateChecker.fetchBodyOverride = (_) async => null;

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
    await tester.pump(const Duration(milliseconds: 300));
  }

  Image splashBannerImage(WidgetTester tester) {
    final poster = find.byType(EvolveSplashPoster);
    expect(poster, findsOneWidget);
    final imageFinder = find.descendant(
      of: poster,
      matching: find.byType(Image),
    );
    expect(imageFinder, findsOneWidget);
    return tester.widget<Image>(imageFinder);
  }

  testWidgets(
    '390x844 Android splash shows full banner with contain fit and login UI',
    (tester) async {
      try {
        await pumpAndroidSplash(tester, viewport: const Size(390, 844));

        final image = splashBannerImage(tester);
        expect(image.fit, BoxFit.contain);
        expect(image.fit, isNot(BoxFit.cover));
        expect(EvolveSplashPoster.usesProportionalFit, isTrue);

        expect(find.text('Sign in'), findsWidgets);
        expect(find.text('EVOLVE'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    '360x800 Android splash keeps contain fit without cover crop regression',
    (tester) async {
      try {
        await pumpAndroidSplash(tester, viewport: const Size(360, 800));

        final image = splashBannerImage(tester);
        expect(image.fit, BoxFit.contain);
        expect(image.fit, isNot(BoxFit.cover));

        expect(find.text('Sign in'), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}