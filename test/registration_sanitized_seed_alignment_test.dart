import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';

import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_account_privacy.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_network_coordinator.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

PercLedger _launchedSeedLedger({int extraBlocks = 3}) {
  final seed = PercLedger.empty();
  seed.ensureTreasuryAccount();
  seed.setupTreasuryPassword('password12345');
  seed.launchBlockchain();
  seed.consumeBlockchainLaunchEvent();
  for (var i = 0; i < extraBlocks; i++) {
    seed.blocks.add(
      PercBlock(
        index: seed.blocks.length,
        timestamp: DateTime.utc(2026, 3, 1, 12, i),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'seed block $i',
      ),
    );
  }
  return seed;
}

PercLedger _sanitizedSeed(PercLedger seed) {
  return PercLedger.fromJson(
    PercAccountPrivacy.sanitizeLedgerForPublic(seed.toJson()),
  );
}

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
    PercNetworkCoordinator.instance.clearTestSeedLedger();
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
  });

  test('sanitized seed tip hash matches canonical seed', () {
    final seed = _launchedSeedLedger();
    final sanitized = _sanitizedSeed(seed);
    expect(PercChainTip.hash(sanitized), PercChainTip.hash(seed));
  });

  test('resetFromSeedLedger canonicalizes aliased treasury without duplicate', () {
    final seed = _launchedSeedLedger();
    expect(
      seed.accounts.containsKey(PercChainConstants.treasuryUsername),
      isTrue,
    );
    final sanitizedJson =
        PercAccountPrivacy.sanitizeLedgerForPublic(seed.toJson());
    final sanitized = PercLedger.fromJson(sanitizedJson);
    final treasuryAlias =
        PercAccountPrivacy.obfuscateUsername(PercChainConstants.treasuryUsername);

    expect(
      (sanitizedJson['accounts'] as Map).containsKey(treasuryAlias),
      isTrue,
    );
    expect(
      sanitized.accounts.containsKey(PercChainConstants.treasuryUsername),
      isTrue,
    );
    expect(sanitized.accounts.containsKey(treasuryAlias), isFalse);

    final local = PercLedger.empty();
    local.resetFromSeedLedger(
      sanitized,
      expectedTipHash: PercChainTip.hash(seed),
    );

    expect(local.accounts.containsKey(PercChainConstants.treasuryUsername),
        isTrue);
    expect(local.accounts.containsKey(treasuryAlias), isFalse);
    expect(PercChainTip.hash(local), PercChainTip.hash(seed));
  });

  test('registration through sanitized seed fetch path aligns chain', () async {
    final seed = _launchedSeedLedger(extraBlocks: 4);
    final sanitized = _sanitizedSeed(seed);
    PercNetworkCoordinator.instance.registerTestSeedLedger(sanitized);

    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('sanitizeduser', 'password12345');

    final ledger = PercLedgerHub.instance.ledger;
    expect(ledger.blockHeight, PercChainTip.height(seed));
    expect(PercChainTip.hash(ledger), PercChainTip.hash(seed));
    expect(ledger.account('sanitizeduser'), isNotNull);
    expect(
      ledger.accounts.containsKey(PercChainConstants.treasuryUsername),
      isTrue,
    );
    expect(wallet.isWalletConnectComplete, isTrue);
    expect(wallet.isNetworkSynced, isTrue);
  });
}