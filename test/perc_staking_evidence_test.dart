import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_account.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_faucet.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_staking.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

final _scratch = r'C:\Users\rgsne\AppData\Local\Temp\grok-goal-1f47cc190d87\implementer';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
  ledger.register('staker', 'password123');
}

void _writeLog(String name, List<String> lines) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch\\$name').writeAsStringSync(lines.join('\n'));
}

void main() {
  test('evidence: staking rate probe', () {
    final lines = <String>[
      '=== staking rate probe ===',
      '0 PERC -> ${PercStaking.rewardForBalance(PercAmount.zero).displayFixed8}',
      '1 PERC -> ${PercStaking.rewardForBalance(PercAmount.fromPerc(1)).displayFixed8}',
      '2 PERC -> ${PercStaking.rewardForBalance(PercAmount.fromPerc(2)).displayFixed8}',
      '0.5 PERC -> ${PercStaking.rewardForBalance(PercAmount.fromPerc(0.5)).displayFixed8}',
      '100 PERC -> ${PercStaking.rewardForBalance(PercAmount.fromPerc(100)).displayFixed8}',
    ];
    expect(PercStaking.rewardForBalance(PercAmount.fromPerc(1)).microUnits, 5);
    expect(PercStaking.rewardForBalance(PercAmount.fromPerc(2)).microUnits, 10);
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(1)),
      isNot(equals(PercStaking.rewardForBalance(PercAmount.fromPerc(100)))),
    );
    lines.add('OBSERVATION: 1 PERC and 100 PERC rewards differ (proportional)');
    _writeLog('staking_rate_probe.log', lines);
  });

  test('evidence: offline staking settlement', () {
    final network = PercLedger.empty();
    _seed(network);
    network.register('bob', 'password123');
    network.creditScenario(username: 'staker', percentChance: 50);
    network.account('staker')!.balance = PercAmount.fromPerc(1.5);

    final offline = PercLedger.fromJson(network.toJson());
    final treasuryBefore =
        network.account(PercChainConstants.treasuryUsername)!.balance;
    final stakerBefore = offline.account('staker')!.balance;

    network.creditScenario(username: 'bob', percentChance: 30);

    final stakerAfter = network.account('staker')!;
    final expectedReward =
        PercStaking.rewardForBalance(PercAmount.fromPerc(1.5));

    offline.importPeerLedger(
      network,
      expectedTipHash: PercChainTip.hash(network),
    );
    offline.login('staker', 'password123');
    offline.reconcileSessionStakingFromChain('staker', applyCredits: true);

    final lines = <String>[
      '=== offline staking settlement ===',
      'wallet_a=staker (offline during bob scenario)',
      'wallet_b=bob (scenario runner)',
      'treasury_before=${treasuryBefore.displayFixed8}',
      'treasury_after=${network.account(PercChainConstants.treasuryUsername)!.balance.displayFixed8}',
      'staker_balance_before_offline=${stakerBefore.displayFixed8}',
      'staker_balance_after_network=${stakerAfter.balance.displayFixed8}',
      'staker_staking_after_network=${stakerAfter.cumulativeStakingEarned.displayFixed8}',
      'staker_balance_after_import=${offline.account('staker')!.balance.displayFixed8}',
      'staker_staking_after_import=${offline.account('staker')!.cumulativeStakingEarned.displayFixed8}',
      'expected_reward=${expectedReward.displayFixed8}',
    ];
    expect(stakerAfter.cumulativeStakingEarned, expectedReward);
    expect(offline.account('staker')!.cumulativeStakingEarned, expectedReward);
    lines.add('OBSERVATION: offline wallet A caught up proportional staking after import');
    _writeLog('offline_staking_settlement.log', lines);
  });

  test('evidence: treasury staking funding', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'staker', percentChance: 50);
    ledger.account('staker')!.balance = PercAmount.fromPerc(2);
    ledger.account('bob')!.balance = PercAmount.fromPerc(1);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final treasuryBefore = treasury.balance;
    final treasuryStakingBefore = treasury.cumulativeStakingEarned;

    ledger.creditScenario(username: 'bob', percentChance: 20);

    final stakerReward = PercStaking.rewardForBalance(PercAmount.fromPerc(2));
    final bobReward = PercStaking.rewardForBalance(PercAmount.fromPerc(1));
    final scenarioReward =
        PercFaucet.computeScenarioReward(percentChance: 20).total;
    final totalHolderRewards = stakerReward + bobReward;

    final lines = <String>[
      '=== treasury staking funding ===',
      'treasury_balance_before=${treasuryBefore.displayFixed8}',
      'treasury_balance_after=${treasury.balance.displayFixed8}',
      'treasury_cumulative_staking_before=${treasuryStakingBefore.displayFixed8}',
      'treasury_cumulative_staking_after=${treasury.cumulativeStakingEarned.displayFixed8}',
      'holder_rewards_sum=${totalHolderRewards.displayFixed8}',
      'scenario_payout=${scenarioReward.displayFixed8}',
    ];
    expect(treasury.cumulativeStakingEarned, treasuryStakingBefore);
    expect(
      treasury.transactions.where(
        (t) =>
            t.kind == PercTxKind.stakingReward &&
            t.toUsername == PercChainConstants.treasuryUsername,
      ),
      isEmpty,
    );
    expect(
      treasury.balance,
      treasuryBefore - totalHolderRewards - scenarioReward,
    );
    lines.add('OBSERVATION: treasury debits equal sum of holder rewards; treasury earns no staking');
    _writeLog('treasury_staking_funding.log', lines);
  });

  test('evidence: login full sync staking', () async {
    PercLedgerHub.resetForTest();
    final store = PercWalletStoreMemory();
    await PercLedgerHub.instance.initialize(store);
    final hub = PercLedgerHub.instance;
    _seed(hub.ledger);
    hub.ledger.register('bob', 'password123');
    hub.ledger.creditScenario(username: 'staker', percentChance: 40);
    hub.ledger.account('staker')!.balance = PercAmount.fromPerc(1);

    final remote = PercLedger.fromJson(hub.ledger.toJson());
    remote.creditScenario(username: 'bob', percentChance: 25);
    final expectedReward = PercStaking.rewardForBalance(PercAmount.fromPerc(1));

    hub.importPeerLedger(remote, expectedTipHash: PercChainTip.hash(remote));
    hub.ledger.login('staker', 'password123');
    final owedAtLogin = hub.ledger.sessionStakingOwedCalculated;
    hub.ledger.reconcileSessionStakingFromChain('staker', applyCredits: true);

    final lines = <String>[
      '=== login full sync staking ===',
      'staking_owed_at_login=${owedAtLogin.displayFixed8}',
      'expected_reward=${expectedReward.displayFixed8}',
      'cumulative_after_sync=${hub.ledger.sessionAccount!.cumulativeStakingEarned.displayFixed8}',
      'balance_after_sync=${hub.ledger.sessionAccount!.balance.displayFixed8}',
    ];
    expect(owedAtLogin, expectedReward);
    expect(hub.ledger.sessionAccount!.cumulativeStakingEarned, expectedReward);
    lines.add('OBSERVATION: login calculated owed; full sync applied chain staking credits');
    _writeLog('login_full_sync_staking.log', lines);
  });
}