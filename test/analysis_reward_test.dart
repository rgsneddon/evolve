import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';

import 'test_helpers.dart';

Future<void> _seedWallet(PercWalletProvider wallet) async {
  await wallet.setupTreasuryPassword('password12345');
  await wallet.register('analyst', 'password12345');
}

void main() {
  test('percent chance calculate credits Perccent faucet', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await _seedWallet(wallet);

    final evolve = EvolveProvider();
    evolve.analysisRewardHandler = ({
      required AnalysisMode mode,
      required double outcomeScore,
      String? memo,
      double? continuumScs,
      double? vortexScs,
      double? shearScs,
      double? resistanceScs,
      double? flowScs,
    }) =>
        wallet.creditAnalysis(
          mode: mode,
          outcomeScore: outcomeScore,
          memo: memo,
          continuumScs: continuumScs,
          vortexScs: vortexScs,
          shearScs: shearScs,
          resistanceScs: resistanceScs,
          flowScs: flowScs,
        );

    evolve.setMode(AnalysisMode.percentChance);
    evolve.updateInput(scenarioWithConstructs(
      posedQuestion: 'What is the chance of policy reform this year?',
    ));
    await evolve.calculate();

    expect(evolve.result, isNotNull);
    final rewardTx = wallet.transactions.firstWhere(
      (t) => t.kind == PercTxKind.scenarioReward,
    );
    expect(rewardTx.scenarioLabel, contains('Percent chance'));
    expect(wallet.balance.microUnits, greaterThan(0));
  });

  test('social cohesion calculate credits Perccent faucet from refined SCS', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await _seedWallet(wallet);

    final evolve = EvolveProvider();
    evolve.analysisRewardHandler = ({
      required AnalysisMode mode,
      required double outcomeScore,
      String? memo,
      double? continuumScs,
      double? vortexScs,
      double? shearScs,
      double? resistanceScs,
      double? flowScs,
    }) =>
        wallet.creditAnalysis(
          mode: mode,
          outcomeScore: outcomeScore,
          memo: memo,
          continuumScs: continuumScs,
          vortexScs: vortexScs,
          shearScs: shearScs,
          resistanceScs: resistanceScs,
          flowScs: flowScs,
        );

    evolve.setMode(AnalysisMode.cohesionScore);
    evolve.updateInput(scenarioWithConstructs(
      topic: 'Community trust after protests',
      posedQuestion: 'Mayor statement on weekend protests.',
    ));
    await evolve.calculate();

    expect(evolve.result, isNotNull);
    final scs = evolve.result!.core.refinedScs;
    expect(scs, inInclusiveRange(20, 87));
    final rewardTx = wallet.transactions.firstWhere(
      (t) => t.kind == PercTxKind.scenarioReward,
    );
    expect(rewardTx.scenarioLabel, contains('Social cohesion'));
    expect(wallet.lastReward?.percentChance, scs);
    expect(wallet.balance.microUnits, greaterThan(0));
  });

  test('evolve calculate wires analysis reward handler for both modes', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await _seedWallet(wallet);

    final evolve = EvolveProvider();
    evolve.analysisRewardHandler = ({
      required AnalysisMode mode,
      required double outcomeScore,
      String? memo,
      double? continuumScs,
      double? vortexScs,
      double? shearScs,
      double? resistanceScs,
      double? flowScs,
    }) =>
        wallet.creditAnalysis(
          mode: mode,
          outcomeScore: outcomeScore,
          memo: memo,
          continuumScs: continuumScs,
          vortexScs: vortexScs,
          shearScs: shearScs,
          resistanceScs: resistanceScs,
          flowScs: flowScs,
        );

    evolve.setMode(AnalysisMode.cohesionScore);
    evolve.updateInput(scenarioWithConstructs(topic: 'Neighbourhood cohesion'));
    await evolve.calculate();

    final rewardTx = wallet.transactions.firstWhere(
      (t) => t.kind == PercTxKind.scenarioReward,
    );
    expect(rewardTx.scenarioLabel, contains('Social cohesion'));
    expect(rewardTx.kind.wireName, 'scenarioReward');
  });
}