import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_account_privacy.dart';
import 'package:evolve/perc/services/perc_chain_alignment.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_network_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

PercLedger _launchedLedger({int extraBlocks = 2}) {
  final ledger = PercLedger.empty();
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
  for (var i = 0; i < extraBlocks; i++) {
    ledger.blocks.add(
      PercBlock(
        index: ledger.blocks.length,
        timestamp: DateTime.utc(2026, 1, 1, 0, i),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'seed block $i',
      ),
    );
  }
  return ledger;
}

void main() {
  test('SeedAlignmentTarget.fromLedger matches sanitized seed tip', () {
    final seed = _launchedLedger();
    final sanitized = PercLedger.fromJson(
      PercAccountPrivacy.sanitizeLedgerForPublic(seed.toJson()),
    );
    final target = SeedAlignmentTarget.fromLedger(sanitized);
    expect(target.chainId, PercChainAlignment.effectiveChainId(seed));
    expect(target.height, PercChainTip.height(seed));
    expect(target.tipHash, PercChainTip.hash(seed));
  });

  test('isAlignedWithSeed matches height tip and chain id', () {
    final seed = _launchedLedger();
    final local = PercLedger.fromJson(seed.toJson());
    expect(
      PercChainAlignment.isAlignedWithSeed(
        local: local,
        seedChainId: PercChainConstants.evolutionaryChainId,
        seedHeight: PercChainTip.height(seed),
        seedTipHash: PercChainTip.hash(seed),
      ),
      isTrue,
    );
  });

  test('isBehindOrTipMismatch detects shorter local chain', () {
    final seed = _launchedLedger(extraBlocks: 4);
    final local = _launchedLedger(extraBlocks: 1);
    expect(
      PercChainAlignment.isBehindOrTipMismatch(
        local: local,
        seedHeight: PercChainTip.height(seed),
        seedTipHash: PercChainTip.hash(seed),
      ),
      isTrue,
    );
  });

  test('syncStateForSeed reports heightMismatch on equal-height tip drift', () {
    final local = _launchedLedger(extraBlocks: 2);
    expect(
      PercChainAlignment.syncStateForSeed(
        local: local,
        seedHeight: PercChainTip.height(local),
        seedTipHash: 'different-tip',
      ),
      PercNetworkSyncState.heightMismatch,
    );
  });
}