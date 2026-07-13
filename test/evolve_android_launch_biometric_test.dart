import 'package:evolve/perc/perc_app_version.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/app_update_check.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/services/wallet_biometric_credential_store.dart';
import 'package:evolve/perc/widgets/registration_seed_setup_dialog.dart';
import 'package:evolve/perc/widgets/wallet_auth_panel.dart';
import 'package:evolve/perc/widgets/wallet_biometric_auth_ui.dart';
import 'package:evolve/perc/screens/wallet_screen.dart';
import 'package:evolve/screens/evolve_loading_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'test_locale_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    PercWalletProvider.sessionTimeoutEnabled = true;
    WalletBiometricAuthUi.storeOverride = null;
    WalletBiometricAuthUi.androidPlatformOverrideForTest = null;
    EvolveLoadingScreen.introDurationOverride = null;
    AppUpdateChecker.fetchBodyOverride = null;
    AppUpdateChecker.headProbeOverride = null;
    PercLedgerHub.resetForTest();
  });

  WalletBiometricCredentialStore testStore({
    Map<String, String>? memory,
    Future<bool> Function(String reason)? authenticate,
  }) {
    return WalletBiometricCredentialStore(
      androidPlatformOverride: true,
      memoryStorage: memory ?? <String, String>{},
      authenticateOverride: authenticate ?? (_) async => true,
      availabilityOverride: () async => true,
    );
  }

  testWidgets(
    'returning Android user with stored credentials is biometric-prompted on launch',
    (tester) async {
      WalletBiometricAuthUi.androidPlatformOverrideForTest = true;
      var authPrompts = 0;
      final store = testStore(
        authenticate: (_) async {
          authPrompts++;
          return true;
        },
      );
      await store.saveCredentials(username: 'alice', password: 'password12345');
      WalletBiometricAuthUi.storeOverride = store;

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.register('alice', 'password12345');
      await wallet.completeRegistrationSeedSetup(enableSeed: false);
      await wallet.logout();

      final locale = await createTestLocaleProvider();
      final evolve = EvolveProvider();
      await evolve.initialize();
      EvolveLoadingScreen.introDurationOverride = Duration.zero;
      AppUpdateChecker.fetchBodyOverride = (_) async =>
          '{"version":"4.1.3","build_number":"165","app_name":"evolve"}';

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
      await tester.pump(const Duration(milliseconds: 200));

      expect(authPrompts, 1);
      expect(wallet.isLoggedIn, isTrue);
    },
  );

  testWidgets(
    'wallet tab login auto-prompts biometric when credentials are stored',
    (tester) async {
      WalletBiometricAuthUi.androidPlatformOverrideForTest = true;
      var authPrompts = 0;
      final store = testStore(
        authenticate: (_) async {
          authPrompts++;
          return true;
        },
      );
      await store.saveCredentials(username: 'alice', password: 'password12345');
      WalletBiometricAuthUi.storeOverride = store;

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.register('alice', 'password12345');
      await wallet.completeRegistrationSeedSetup(enableSeed: false);
      await wallet.logout();

      final locale = await createTestLocaleProvider();
      final evolve = EvolveProvider();
      await evolve.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wallet),
            ChangeNotifierProvider.value(value: locale),
            ChangeNotifierProvider.value(value: evolve),
          ],
          child: const MaterialApp(home: WalletScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authPrompts, 1);
      expect(wallet.isLoggedIn, isTrue);
      await wallet.logout();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'loading screen hides update banner when installed matches gh-pages feed',
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

  testWidgets(
    'post-registration seed completion offers biometric enrollment on Android',
    (tester) async {
      WalletBiometricAuthUi.androidPlatformOverrideForTest = true;
      final store = testStore();
      WalletBiometricAuthUi.storeOverride = store;

      PercWalletProvider.sessionTimeoutEnabled = true;
      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.register('bob', 'password12345');
      expect(wallet.pendingSeedSetup, isTrue);

      final locale = await createTestLocaleProvider();
      final evolve = EvolveProvider();
      await evolve.initialize();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wallet),
            ChangeNotifierProvider.value(value: locale),
            ChangeNotifierProvider.value(value: evolve),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RegistrationSeedSetupDialogHost(
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('registration_seed_skip_button')),
      );
      await tester.tap(find.byKey(const Key('registration_seed_skip_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enable biometric sign-in?'), findsOneWidget);
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      expect(wallet.isLoggedIn, isTrue);
      expect(await store.hasStoredCredentials(), isTrue);

      await wallet.logout();
      await tester.pump(const Duration(hours: 8));
    },
  );
}