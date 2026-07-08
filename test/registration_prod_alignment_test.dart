import 'dart:io';

import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_chain_alignment.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_client.dart';
import 'package:evolve/perc/services/perc_network_config.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

final _scratch = Platform.environment['SCRATCH'] ??
    r'C:\Users\rgsne\AppData\Local\Temp\grok-goal-cb031749c6db\implementer';

void _writeLog(String filename, String body) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch${Platform.pathSeparator}$filename').writeAsStringSync(body);
}

bool _ledgerJsonIsPrivacySafe(Map<String, dynamic> ledger) {
  final accounts = ledger['accounts'];
  if (accounts is! Map || accounts.isEmpty) return true;
  for (final account in accounts.values) {
    if (account is Map && account.containsKey('passwordHash')) return false;
  }
  return true;
}

/// Evidence: full provider.register() adopt + align + publish on Render seed.
void main() {
  const skipLive =
      bool.fromEnvironment('PERC_SKIP_LIVE_SEED', defaultValue: false);
  const prodBase = 'https://evolve-perc-internet.onrender.com';

  setUp(() {
    PercLedgerHub.resetForTest();
    PercNetworkConfig.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    PercNetworkCoordinator.disableLiveNodesForTests = false;
    PercNetworkConfig.setCachedForTest(
      const PercNetworkConfig(
        rendezvousUrl: prodBase,
        seedUsername: PercChainConstants.seedUsername,
        networkGenesisRevision: 2,
        publicEndpointOverride: prodBase,
        publicIpLookupUrls: [],
      ),
    );
  });

  tearDown(() async {
    PercNetworkCoordinator.disableLiveNodesForTests = true;
    await PercLedgerHub.instance.network.onSessionEnded();
    PercNetworkConfig.resetForTest();
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test(
    'prod provider.register adopts seed ledger aligns and publishes',
    () async {
      if (skipLive) {
        _writeLog(
          'prod_registration_alignment.log',
          'skipped: PERC_SKIP_LIVE_SEED=true\n',
        );
        return;
      }

      final client = PercNetworkClient();
      var preStatus = await client.fetchStatus(prodBase);
      var preLedger = await client.fetchLedger(prodBase);
      for (var attempt = 0; preLedger == null && attempt < 4; attempt++) {
        await Future<void>.delayed(Duration(seconds: 2 + attempt));
        preStatus = await client.fetchStatus(prodBase);
        preLedger = await client.fetchLedger(prodBase);
      }

      if (preLedger == null) {
        _writeLog(
          'prod_registration_alignment.log',
          'skipped: seed ledger fetch failed at $prodBase after retries\n'
          'statusReachable=${preStatus != null}\n',
        );
        return;
      }

      final privacySafe = _ledgerJsonIsPrivacySafe(preLedger.toJson());
      final canonicalTip = PercChainTip.hash(preLedger);
      final canonicalHeight = PercChainTip.height(preLedger);
      final canonicalChainId = PercChainAlignment.effectiveChainId(preLedger);
      final statusTip = preStatus?.tipHash ?? '';
      final statusHeight = preStatus?.blockHeight ?? 0;

      final username =
          'align_${DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36)}';
      const password = 'password12345';

      final wallet = PercWalletProvider(store: PercWalletStoreMemory());
      PercNetworkCoordinator.disableLiveNodesForTests = true;
      await wallet.initialize();
      PercNetworkCoordinator.disableLiveNodesForTests = false;
      final hub = PercLedgerHub.instance;
      hub.ledger.ensureTreasuryAccount();
      hub.ledger.setupTreasuryPassword(password);
      hub.ledger.networkGenesisRevision = 2;

      expect(hub.ledger.account(username), isNull);

      await wallet.register(username, password);

      final coordinator = hub.network;
      final ledger = hub.ledger;
      final clientTip = PercChainTip.hash(ledger);
      final clientHeight = PercChainTip.height(ledger);
      final clientChainId = PercChainAlignment.effectiveChainId(ledger);
      final ledgerAligned = PercChainAlignment.isAlignedWithSeed(
        local: ledger,
        seedChainId: canonicalChainId,
        seedHeight: canonicalHeight,
        seedTipHash: canonicalTip,
      );

      _writeLog(
        'prod_registration_alignment.log',
        'path=provider.register\n'
        'base=$prodBase\n'
        'privacySafe=$privacySafe\n'
        'username=$username\n'
        'statusTip=$statusTip\n'
        'statusHeight=$statusHeight\n'
        'canonicalTip=$canonicalTip\n'
        'canonicalHeight=$canonicalHeight\n'
        'canonicalChainId=$canonicalChainId\n'
        'clientTip=$clientTip\n'
        'clientHeight=$clientHeight\n'
        'clientChainId=$clientChainId\n'
        'ledgerAligned=$ledgerAligned\n'
        'statusMatchesCanonicalTip=${statusTip == canonicalTip}\n'
        'statusMatchesCanonicalHeight=${statusHeight == canonicalHeight}\n'
        'seedConnected=${coordinator.isConnectedToSeed}\n'
        'registrationAwaiting=${wallet.registrationAwaitingSeedAlignment}\n'
        'walletConnectComplete=${wallet.isWalletConnectComplete}\n'
        'pendingRecovery=${coordinator.hasPendingRegistrationRecovery}\n'
        'accountPresent=${ledger.account(username) != null}\n'
        'hasAppAccess=${wallet.hasAppAccess}\n'
        'note=clients align via imported /perc/ledger tip; stale /perc/status is non-authoritative\n',
      );

      expect(ledger.account(username), isNotNull);
      expect(ledgerAligned, isTrue);
      expect(clientTip, canonicalTip);
      expect(clientHeight, canonicalHeight);
      expect(clientChainId, canonicalChainId);
      expect(wallet.registrationAwaitingSeedAlignment, isFalse);
      expect(coordinator.hasPendingRegistrationRecovery, isFalse);
      expect(wallet.isWalletConnectComplete, isTrue);
      expect(wallet.hasAppAccess, isTrue);
      expect(coordinator.isConnectedToSeed, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}