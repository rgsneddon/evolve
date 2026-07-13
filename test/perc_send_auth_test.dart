import 'dart:io';

import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/wallet_biometric_credential_store.dart';
import 'package:evolve/perc/services/wallet_send_auth_gate.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

int _outboundTransferCount() {
  return PercLedgerHub.instance.ledger
      .account('alice')!
      .transactions
      .where((t) => t.kind == PercTxKind.transfer)
      .length;
}

Future<PercWalletProvider> _fundedSender() async {
  final wallet = PercWalletProvider(store: PercWalletStoreMemory());
  await wallet.initialize();
  await wallet.setupTreasuryPassword('password12345');
  await wallet.register('alice', 'password12345');
  PercLedgerHub.instance.ledger.launchBlockchain();
  final credit = await wallet.creditScenario(outcomeScore: 80, memo: 'fund');
  expect(credit?.status, PercFaucetCreditStatus.credited);
  PercLedgerHub.instance.ledger.register('bob', 'password12345');
  return wallet;
}

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    WalletSendAuthGate.biometricStoreOverride = null;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercLedgerHub.resetForTest();
    WalletSendAuthGate.biometricStoreOverride = null;
  });

  test('send without auth password is rejected before transfer', () async {
    final wallet = await _fundedSender();
    final bobAddr = PercLedgerHub.instance.ledger.account('bob')!.address;
    final balanceBefore = wallet.balance;
    final transfersBefore = _outboundTransferCount();

    await wallet.send(toAddress: bobAddr, amountText: '0.00000001');

    expect(wallet.errorMessage, 'wallet_err_send_auth_required');
    expect(wallet.balance, balanceBefore);
    expect(_outboundTransferCount(), transfersBefore);
  });

  test('send with wrong auth password is rejected', () async {
    final wallet = await _fundedSender();
    final bobAddr = PercLedgerHub.instance.ledger.account('bob')!.address;

    final transfersBefore = _outboundTransferCount();
    await wallet.send(
      toAddress: bobAddr,
      amountText: '0.00000001',
      sendAuthPassword: 'wrong-password',
    );

    expect(wallet.errorMessage, 'wallet_err_invalid_password');
    expect(_outboundTransferCount(), transfersBefore);
  });

  test('send with correct auth password succeeds', () async {
    final wallet = await _fundedSender();
    final bobAddr = PercLedgerHub.instance.ledger.account('bob')!.address;

    await wallet.send(
      toAddress: bobAddr,
      amountText: '0.00000001',
      sendAuthPassword: 'password12345',
    );

    expect(wallet.errorMessage, isNull);
    expect(wallet.statusMessage, isNotNull);
    expect(_outboundTransferCount(), greaterThan(0));
  });

  test('creditScenario and creditAnalysis do not require send auth password',
      () async {
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');
    PercLedgerHub.instance.ledger.launchBlockchain();

    final percent = await wallet.creditScenario(outcomeScore: 42, memo: 'pc');
    expect(percent?.status, PercFaucetCreditStatus.credited);
    expect(wallet.errorMessage, isNull);
  });

  test('send wiring includes WalletSendAuthGate before wallet.send', () {
    final actions =
        File('lib/perc/services/perc_send_receive_actions.dart').readAsStringSync();
    final provider =
        File('lib/perc/providers/perc_wallet_provider.dart').readAsStringSync();
    expect(actions, contains('WalletSendAuthGate.requestAuthorization'));
    expect(actions, contains('sendAuthPassword'));
    expect(provider, contains('verifySendAuthPassword'));
    expect(provider, contains('wallet_err_send_auth_required'));
    expect(provider, contains('sendAuthPassword'));
    expect(provider.contains('sendAuthPassword'), isTrue);
    final creditIdx = provider.indexOf('Future<PercFaucetCreditResult?> creditScenario');
    final sendAuthIdx = provider.indexOf('verifySendAuthPassword');
    expect(creditIdx, greaterThan(0));
    expect(sendAuthIdx, greaterThan(0));
    expect(provider.substring(creditIdx, creditIdx + 800), isNot(contains('sendAuthPassword')));
  });

  test('biometric unlock password allows send when credentials match session',
      () async {
    final memory = <String, String>{};
    WalletSendAuthGate.biometricStoreOverride = WalletBiometricCredentialStore(
      androidPlatformOverride: true,
      memoryStorage: memory,
      authenticateOverride: (_) async => true,
      availabilityOverride: () async => true,
    );
    await WalletSendAuthGate.biometricStoreOverride!
        .saveCredentials(username: 'alice', password: 'password12345');

    final wallet = await _fundedSender();
    final creds = await WalletSendAuthGate.biometricStoreOverride!
        .unlockWithBiometric(localizedReason: 'test');
    expect(creds, isNotNull);
    expect(wallet.verifySendAuthPassword(creds!.password), isTrue);

    await wallet.send(
      toAddress: PercLedgerHub.instance.ledger.account('bob')!.address,
      amountText: '0.00000001',
      sendAuthPassword: creds.password,
    );
    expect(wallet.errorMessage, isNull);
  });

  test('biometric failure leaves send blocked without provider password', () async {
    final memory = <String, String>{};
    WalletSendAuthGate.biometricStoreOverride = WalletBiometricCredentialStore(
      androidPlatformOverride: true,
      memoryStorage: memory,
      authenticateOverride: (_) async => false,
      availabilityOverride: () async => true,
    );
    await WalletSendAuthGate.biometricStoreOverride!
        .saveCredentials(username: 'alice', password: 'password12345');

    final wallet = await _fundedSender();
    final creds = await WalletSendAuthGate.biometricStoreOverride!
        .unlockWithBiometric(localizedReason: 'test');
    expect(creds, isNull);

    await wallet.send(
      toAddress: PercLedgerHub.instance.ledger.account('bob')!.address,
      amountText: '0.00000001',
    );
    expect(wallet.errorMessage, 'wallet_err_send_auth_required');
  });
}