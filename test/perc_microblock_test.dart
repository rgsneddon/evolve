import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chronoflux_micro_verifier.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  setUp(() {
    PercChainConstants.microblocksPerBlockOverride = 3;
    PercChainConstants.microblocksPerWardOverride = 3;
  });

  tearDown(() {
    PercChainConstants.microblocksPerBlockOverride = null;
    PercChainConstants.microblocksPerWardOverride = null;
  });

  test('Chronoflux micro verifier self-checks continuum equation', () {
    const verifier = PercChronofluxMicroVerifier();
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of reform passing?',
      topic: 'reform',
    );
    final result = verifier.verify(input);
    expect(result.selfConsistent, isTrue);
    expect(result.fingerprint, isNotEmpty);
    expect(result.continuumPercent, inInclusiveRange(8, 92));
  });

  test('keystrokes advance microblocks and seal block without calculate', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    const input = ScenarioInput(posedQuestion: 'Test scenario');

    for (var i = 0; i < 2; i++) {
      final step = ledger.recordMicroblock(input: input);
      expect(step.recorded, isTrue);
      expect(step.blockSealed, isFalse);
      expect(ledger.microblockCount, i + 1);
      expect(ledger.microblockLog.length, i + 1);
    }

    final seal = ledger.recordMicroblock(input: input);
    expect(seal.blockSealed, isTrue);
    expect(seal.wardAdvanced, isTrue);
    expect(ledger.microblockCount, 0);
    expect(ledger.microblockLog, isEmpty);
    expect(ledger.blocks.length, 1);
    expect(ledger.blocks.first.microblockSeal, isTrue);
    expect(
      ledger.blocks.first.transactions.any(
        (t) => t.kind == PercTxKind.chronofluxMicroblock,
      ),
      isTrue,
    );
    expect(
      ledger.blocks.first.transactions.any(
        (t) => t.kind == PercTxKind.genesisRenewal,
      ),
      isFalse,
    );
    expect(
      ledger.blocks.first.transactions.any(
        (t) => t.kind == PercTxKind.stakingReward,
      ),
      isFalse,
    );
  });

  test('microblock state persists in ledger json round-trip', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.recordMicroblock(input: const ScenarioInput(posedQuestion: 'A'));
    ledger.recordMicroblock(input: const ScenarioInput(posedQuestion: 'AB'));

    final restored = PercLedger.fromJson(ledger.toJson());
    expect(restored.microblockCount, 2);
    expect(restored.totalMicroblocks, 2);
    expect(restored.lastChronofluxFingerprint, isNotNull);
    expect(restored.microblockLog.length, 2);
    expect(restored.microblockLog.first.wardIndex, 0);
    expect(restored.microblockLog.last.wardMicroblock, 2);
  });

  test('fair-usage ward log clears when ward fills before seal cycle ends', () {
    PercChainConstants.microblocksPerBlockOverride = 6;
    PercChainConstants.microblocksPerWardOverride = 3;

    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    const input = ScenarioInput(posedQuestion: 'Fair usage keystroke');

    ledger.recordMicroblock(input: input);
    ledger.recordMicroblock(input: input);
    final wardEnd = ledger.recordMicroblock(input: input);

    expect(wardEnd.wardAdvanced, isTrue);
    expect(wardEnd.blockSealed, isFalse);
    expect(ledger.microblockCount, 3);
    expect(ledger.microblockLog, isEmpty);

    ledger.recordMicroblock(input: input);
    expect(ledger.microblockLog.length, 1);
    expect(ledger.microblockLog.first.wardIndex, 1);
    expect(ledger.microblockLog.first.wardMicroblock, 1);
  });

  test('seal cycle prunes ward log without treasury cycle print', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    const input = ScenarioInput(posedQuestion: 'Prune log');

    final before = ledger.treasuryBalance;
    for (var i = 0; i < 2; i++) {
      ledger.recordMicroblock(input: input);
    }
    final seal = ledger.recordMicroblock(input: input);

    expect(seal.blockSealed, isTrue);
    expect(seal.wardAdvanced, isTrue);
    expect(ledger.microblockLog, isEmpty);
    // Treasury emits only on scenario analysis, not on microblock seal.
    expect(before, PercAmount.zero);
    expect(ledger.treasuryBalance, before);
  });

  test('microblocks skipped before blockchain launch', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    final result = ledger.recordMicroblock(input: const ScenarioInput());
    expect(result.recorded, isFalse);
    expect(ledger.microblockCount, 0);
  });
}