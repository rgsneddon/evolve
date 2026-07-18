import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/l10n/wallet_message_localization.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  final strings = AppLocalizations.of(LocaleConfig.defaults);

  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    PercNetworkCoordinator.sessionStartThrowsForTest = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercNetworkCoordinator.sessionStartThrowsForTest = false;
    PercLedgerHub.resetForTest();
  });

  group('WalletMessageLocalization.errorKeyFromException', () {
    test('maps credential and validation failures to specific keys', () {
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError('Unknown account'),
        ),
        'wallet_err_unknown_account',
      );
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError('Invalid password'),
        ),
        'wallet_err_invalid_password',
      );
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError('Username already taken'),
        ),
        'wallet_err_username_taken',
      );
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError(PercAuth.validateUsername('ab')!),
        ),
        'wallet_err_username_length',
      );
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError(PercAuth.validateUsername('Bad-Name')!),
        ),
        'wallet_err_username_chars',
      );
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError(PercAuth.validatePassword('short')!),
        ),
        'wallet_err_password_short',
      );
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError('That username is reserved — choose another'),
        ),
        'wallet_err_username_reserved',
      );
    });

    test('maps network-style failures to seed offline, not generic', () {
      expect(
        WalletMessageLocalization.errorKeyFromException(
          const SocketException('Failed host lookup: seed.example'),
        ),
        'wallet_sync_seed_offline',
      );
      expect(
        WalletMessageLocalization.errorKeyFromException(
          TimeoutException('seed node timed out'),
        ),
        'wallet_sync_seed_offline',
      );
    });

    test('unknown exceptions still map to wallet_err_generic', () {
      expect(
        WalletMessageLocalization.errorKeyFromException(
          StateError('totally unexpected boom 42'),
        ),
        'wallet_err_generic',
      );
      expect(strings.t('wallet_err_generic'), 'Something went wrong — try again');
    });

    test('specific keys resolve to non-generic English copy', () {
      expect(
        strings.t('wallet_err_username_taken'),
        isNot(contains('Something went wrong')),
      );
      expect(
        strings.t('wallet_err_password_short'),
        isNot(contains('Something went wrong')),
      );
    });
  });

  group('PercWalletProvider paths', () {
    test('register validation does not leave wallet_err_generic', () async {
      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.logout();

      await wallet.register('ab', 'password12345');
      expect(wallet.errorMessage, 'wallet_err_username_length');
      expect(wallet.errorMessage, isNot('wallet_err_generic'));

      await wallet.register('valid_user', 'short');
      expect(wallet.errorMessage, 'wallet_err_password_short');
    });

    test('successful register then login leaves errorMessage null', () async {
      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.logout();

      await wallet.register('alice', 'password12345');
      expect(wallet.isLoggedIn, isTrue);
      expect(wallet.errorMessage, isNull);

      await wallet.logout();
      PercNetworkCoordinator.sessionStartThrowsForTest = true;
      await wallet.login('alice', 'password12345');
      expect(wallet.isLoggedIn, isTrue);
      expect(wallet.errorMessage, isNull);
    });

    test('login heals missing passwordSwitchCommit without generic error',
        () async {
      final store = PercWalletStoreMemory();
      final ledger = PercLedger.empty();
      ledger.ensureTreasuryAccount();
      ledger.setupTreasuryPassword('password12345');
      ledger.register('alice', 'password12345');
      final acc = ledger.account('alice')!;
      acc.passwordSwitchCommit = null;
      await store.save(ledger);

      final wallet = PercWalletProvider(store: store);
      await wallet.initialize();
      await wallet.login('alice', 'password12345');

      expect(wallet.isLoggedIn, isTrue);
      expect(wallet.errorMessage, isNull);
    });

    test('tampered passwordSwitchCommit is not wallet_err_generic', () async {
      final store = PercWalletStoreMemory();
      final ledger = PercLedger.empty();
      ledger.ensureTreasuryAccount();
      ledger.setupTreasuryPassword('password12345');
      ledger.register('alice', 'password12345');
      final acc = ledger.account('alice')!;
      acc.passwordSwitchCommit = 'corrupt-commit-value';
      await store.save(ledger);

      final wallet = PercWalletProvider(store: store);
      await wallet.initialize();
      await wallet.login('alice', 'password12345');

      expect(wallet.isLoggedIn, isFalse);
      expect(wallet.errorMessage, 'wallet_err_invalid_password');
      expect(wallet.errorMessage, isNot('wallet_err_generic'));
    });

    test('duplicate register maps to username taken, not generic', () async {
      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      await wallet.initialize();
      await wallet.setupTreasuryPassword('password12345');
      await wallet.logout();
      await wallet.register('alice', 'password12345');
      await wallet.logout();

      await wallet.register('alice', 'password12345');
      expect(wallet.errorMessage, 'wallet_err_username_taken');
      expect(wallet.isLoggedIn, isFalse);
    });
  });
}
