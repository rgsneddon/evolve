import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_dynamic_emission.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

PercEmissionContext _baselineContext() => PercEmissionContext(
      walletCount: 1,
      onlineWalletCount: 0,
      averageBlockTime: PercChainConstants.faucetCooldown,
    );

void main() {
  test('baseline dynamic emission matches faucet-aligned static accrual', () {
    final context = _baselineContext();
    expect(
      PercDynamicEmission.emissionForElapsedSeconds(
        PercChainConstants.faucetCooldown.inSeconds,
        context,
      ),
      PercChainConstants.maxFaucetPayoutPerDraw,
    );
    expect(
      PercDynamicEmission.effectiveEmissionPerMinute(context).microUnits,
      PercChainConstants.treasuryEmissionPerMinute.microUnits,
    );
  });

  test('higher wallet load increases emission', () {
    final low = _baselineContext();
    final high = PercEmissionContext(
      walletCount: 16,
      onlineWalletCount: 4,
      averageBlockTime: PercChainConstants.faucetCooldown,
    );

    expect(
      PercDynamicEmission.effectiveEmissionPerCooldown(high).microUnits,
      greaterThan(PercDynamicEmission.effectiveEmissionPerCooldown(low).microUnits),
    );
    expect(PercDynamicEmission.loadFactorPercent(high), 400);
  });

  test('faster block generation increases emission', () {
    final slow = PercEmissionContext(
      walletCount: 1,
      onlineWalletCount: 0,
      averageBlockTime: const Duration(minutes: 14),
    );
    final fast = PercEmissionContext(
      walletCount: 1,
      onlineWalletCount: 0,
      averageBlockTime: const Duration(minutes: 3),
    );

    expect(
      PercDynamicEmission.blockTimeFactorPercent(fast),
      greaterThan(PercDynamicEmission.blockTimeFactorPercent(slow)),
    );
    expect(
      PercDynamicEmission.effectiveEmissionPerMinute(fast).microUnits,
      greaterThan(PercDynamicEmission.effectiveEmissionPerMinute(slow).microUnits),
    );
  });

  test('ledger context derives load from registered wallets', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');

    final context = PercDynamicEmission.contextFromLedger(ledger);
    expect(context.walletCount, 2);
    expect(PercDynamicEmission.loadFactorPercent(context), 141);
  });

  test('combined factor is capped at 10x baseline', () {
    final hot = PercEmissionContext(
      walletCount: 100,
      onlineWalletCount: 50,
      averageBlockTime: const Duration(seconds: 30),
    );
    expect(PercDynamicEmission.combinedFactorPercent(hot), 1000);
    expect(
      PercDynamicEmission.effectiveEmissionPerCooldown(hot),
      PercAmount(PercChainConstants.maxFaucetPayoutPerDraw.microUnits * 10),
    );
  });
}