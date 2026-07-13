import 'dart:io';

import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/wallet_biometric_credential_store.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/widgets/registration_seed_setup_dialog.dart';
import 'package:evolve/perc/widgets/wallet_auth_panel.dart';
import 'package:evolve/perc/widgets/wallet_biometric_auth_ui.dart';
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
    WalletBiometricAuthUi.storeOverride = null;
    WalletBiometricAuthUi.androidPlatformOverrideForTest = null;
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

  test('MainActivity extends FlutterFragmentActivity for local_auth', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/evolve/chronoflux/MainActivity.kt',
    ).readAsStringSync();
    expect(mainActivity, contains('FlutterFragmentActivity'));
    expect(mainActivity, isNot(contains('FlutterActivity()')));
  });

  test('biometric sign-in affordance gated to Android login with stored creds',
      () {
    final authUi =
        File('lib/perc/widgets/wallet_biometric_auth_ui.dart').readAsStringSync();
    final panel =
        File('lib/perc/widgets/wallet_auth_panel.dart').readAsStringSync();
    final seedDialog = File(
      'lib/perc/widgets/registration_seed_setup_dialog.dart',
    ).readAsStringSync();
    expect(authUi, contains('TargetPlatform.android'));
    expect(authUi, contains('Icons.fingerprint'));
    expect(authUi, contains('offerEnrollmentIfNeeded'));
    final screen =
        File('lib/perc/screens/wallet_screen.dart').readAsStringSync();
    expect(panel, contains('WalletBiometricAuthUi.showBiometricSignIn'));
    expect(panel, contains('offerEnrollmentIfNeeded'));
    expect(panel, contains('credentialsRevision'));
    expect(screen, contains('credentialsRevision'));
    expect(seedDialog, contains('offerEnrollmentIfNeeded'));
    expect(panel, isNot(contains('accountExisted')));
  });

  testWidgets(
    'registration seed enrollment refreshes auth panel biometric button',
    (tester) async {
      WalletBiometricAuthUi.androidPlatformOverrideForTest = true;

      final store = testStore();
      WalletBiometricAuthUi.storeOverride = store;
      PercWalletProvider.sessionTimeoutEnabled = true;

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.register('alice', 'password12345');
      expect(wallet.pendingSeedSetup, isTrue);

      final locale = await createTestLocaleProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wallet),
            ChangeNotifierProvider.value(value: locale),
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
              body: SingleChildScrollView(
                child: WalletAuthPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      expect(find.text('Sign in with biometrics'), findsOneWidget);
    },
  );

  test('registration session can enroll biometric via real credential store',
      () async {
    final store = testStore();

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');
    await wallet.completeRegistrationSeedSetup(enableSeed: false);

    expect(wallet.isLoggedIn, isTrue);
    await store.saveCredentials(username: 'alice', password: 'password12345');
    expect(await store.hasStoredCredentials(), isTrue);
    expect(
      WalletBiometricAuthUi.showBiometricSignIn(
        loginMode: true,
        hasStoredCredentials: await store.hasStoredCredentials(),
      ),
      defaultTargetPlatform == TargetPlatform.android,
    );
  });

  test('unlockWithBiometric reads stored credentials after auth', () async {
    final store = testStore();
    await store.saveCredentials(username: 'alice', password: 'password12345');
    final creds = await store.unlockWithBiometric(
      localizedReason: 'Authenticate to sign in',
    );
    expect(creds?.username, 'alice');
    expect(creds?.password, 'password12345');
  });

  test('stored credentials plus biometric auth complete login', () async {
    final store = testStore();
    await store.saveCredentials(username: 'alice', password: 'password12345');

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');
    await wallet.logout();

    final creds = await store.unlockWithBiometric(
      localizedReason: 'Authenticate to sign in',
    );
    expect(creds, isNotNull);

    await wallet.login(creds!.username, creds.password);
    expect(wallet.isLoggedIn, isTrue);
    expect(wallet.errorMessage, isNull);
  });

  test('biometric auth failure leaves manual login path intact', () async {
    final store = testStore(authenticate: (_) async => false);
    await store.saveCredentials(username: 'alice', password: 'password12345');

    final creds = await store.unlockWithBiometric(
      localizedReason: 'Authenticate to sign in',
    );
    expect(creds, isNull);
  });
}