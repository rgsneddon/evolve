import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
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
  });

  tearDown(() {
    PercChainConstants.microblocksPerBlockOverride = null;
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
    }

    final seal = ledger.recordMicroblock(input: input);
    expect(seal.blockSealed, isTrue);
    expect(ledger.microblockCount, 0);
    expect(ledger.blocks.length, 1);
    expect(ledger.blocks.first.microblockSeal, isTrue);
    expect(
      ledger.blocks.first.transactions.any(
        (t) => t.kind == PercTxKind.chronofluxMicroblock,
      ),
      isTrue,
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
  });

  test('microblocks skipped before blockchain launch', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    final result = ledger.recordMicroblock(input: const ScenarioInput());
    expect(result.recorded, isFalse);
    expect(ledger.microblockCount, 0);
  });
}