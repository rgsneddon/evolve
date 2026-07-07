import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_account.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_faucet.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_staking.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
  ledger.register('staker', 'password123');
}

void main() {
  test('staking rate is 0.00000005 PERC per 1 PERC held', () {
    expect(PercStaking.rewardPerPercHeld.microUnits, 5);
    expect(PercStaking.rewardPerPercHeld.displayFixed8, '0.00000005');
  });

  test('confirmed balance excludes same-block incoming credits', () {
    expect(
      PercStaking.confirmedBalanceForStaking(
        walletBalance: PercAmount.fromPerc(1),
        sameBlockIncoming: PercAmount.fromPerc(1),
      ),
      PercAmount.zero,
    );
    expect(
      PercStaking.confirmedBalanceForStaking(
        walletBalance: PercAmount.fromPerc(2),
        sameBlockIncoming: PercAmount.fromPerc(0.5),
      ),
      PercAmount.fromPerc(1.5),
    );
  });

  test('proportional staking math on representative balances', () {
    expect(PercStaking.rewardForBalance(PercAmount.zero).microUnits, 0);
    expect(PercStaking.rewardForBalance(PercAmount.fromPerc(1)).microUnits, 5);
    expect(PercStaking.rewardForBalance(PercAmount.fromPerc(2)).microUnits, 10);
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(0.5)).microUnits,
      2,
    );
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(1)).microUnits,
      isNot(
        equals(
          PercStaking.rewardForBalance(PercAmount.fromPerc(100)).microUnits,
        ),
      ),
    );
    expect(
      PercStaking.rewardForBalance(PercAmount.fromPerc(100)).microUnits,
      500,
    );
  });

  test('cumulative staking credited on scenario block', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'staker', percentChance: 10);
    ledger.account('staker')!.balance = PercAmount.fromPerc(1);

    ledger.creditScenario(username: 'bob', percentChance: 10);
    final staker = ledger.account('staker')!;
    expect(
      staker.cumulativeStakingEarned,
      PercStaking.rewardForBalance(PercAmount.fromPerc(1)),
    );
    expect(
      staker.transactions.where((t) => t.kind == PercTxKind.stakingReward).length,
      1,
    );
  });

  test('staking pays proportional amount to all holders on block', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'staker', percentChance: 50);
    ledger.account('staker')!.balance = PercAmount.fromPerc(2);
    ledger.account('bob')!.balance = PercAmount.fromPerc(1);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final treasuryBefore = treasury.balance;
    final stakerReward = PercStaking.rewardForBalance(PercAmount.fromPerc(2));
    final bobReward = PercStaking.rewardForBalance(PercAmount.fromPerc(1));

    ledger.creditScenario(username: 'bob', percentChance: 20);

    final staker = ledger.account('staker')!;
    final bob = ledger.account('bob')!;

    expect(staker.cumulativeStakingEarned, stakerReward);
    expect(bob.cumulativeStakingEarned, bobReward);
    expect(
      treasury.balance.microUnits,
      treasuryBefore.microUnits -
          stakerReward.microUnits -
          bobReward.microUnits -
          PercFaucet.computeScenarioReward(percentChance: 20).total.microUnits,
    );
  });

  test('treasury never accrues staking but funds all holder rewards', () {
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
      treasuryBefore - stakerReward - bobReward - scenarioReward,
    );
  });

  test('offline holder receives proportional staking after ledger import', () {
    final network = PercLedger.empty();
    _seed(network);
    network.register('bob', 'password123');

    network.creditScenario(username: 'staker', percentChance: 50);
    network.account('staker')!.balance = PercAmount.fromPerc(1.5);

    final offline = PercLedger.fromJson(network.toJson());
    offline.logout();

    final treasuryBefore =
        network.account(PercChainConstants.treasuryUsername)!.balance;
    network.creditScenario(username: 'bob', percentChance: 30);

    final networkStaker = network.account('staker')!;
    final expectedReward =
        PercStaking.rewardForBalance(PercAmount.fromPerc(1.5));
    expect(networkStaker.cumulativeStakingEarned, expectedReward);
    expect(
      network.account(PercChainConstants.treasuryUsername)!.balance,
      lessThan(treasuryBefore),
    );

    offline.importPeerLedger(
      network,
      expectedTipHash: PercChainTip.hash(network),
    );
    offline.login('staker', 'password123');

    final offlineStaker = offline.account('staker')!;
    expect(offlineStaker.balance, networkStaker.balance);
    expect(offlineStaker.cumulativeStakingEarned, expectedReward);
    expect(
      offlineStaker.transactions.where((t) => t.kind == PercTxKind.stakingReward),
      isNotEmpty,
    );
  });

  test('send and revert blocks do not pay staking', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'staker', percentChance: 50);

    final treasuryBefore =
        ledger.account(PercChainConstants.treasuryUsername)!.balance;
    final stakerBefore = ledger.account('staker')!.balance;

    ledger.send(
      fromUsername: 'staker',
      toAddress: ledger.account('bob')!.address,
      amount: PercAmount.fromPerc(0.00000010),
    );

    expect(
      ledger.blocks.last.transactions.any(
        (t) => t.kind == PercTxKind.stakingReward,
      ),
      isFalse,
    );
    expect(
      ledger.account(PercChainConstants.treasuryUsername)!.balance,
      treasuryBefore,
    );
    expect(ledger.account('staker')!.balance.microUnits, lessThan(stakerBefore.microUnits));
  });

  test('login calculates staking owed from chain', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'staker', percentChance: 10);
    ledger.account('staker')!.balance = PercAmount.fromPerc(1);
    ledger.creditScenario(username: 'bob', percentChance: 10);

    final expected = PercStaking.rewardForBalance(PercAmount.fromPerc(1));
    ledger.login('staker', 'password123');

    expect(ledger.calculateStakingOwed('staker'), expected);
    expect(ledger.sessionStakingOwedCalculated, expected);
  });

  test('network stub holder receives staking after balance merge', () {
    final network = PercLedger.empty();
    _seed(network);
    network.register('alice', 'password123');
    network.register('bob', 'password123');
    network.creditScenario(username: 'alice', percentChance: 50);

    final runner = PercLedger.fromJson(network.toJson());
    runner.register('charlie', 'password123');
    final charlieAddr = runner.account('charlie')!.address;
    runner.accounts['charlie'] = PercAccount(
      username: 'charlie',
      passwordHash: '',
      salt: '',
      address: charlieAddr,
      passwordSet: false,
    );
    runner.account('alice')!.balance = PercAmount.fromPerc(1.5);

    final remote = PercLedger.fromJson(runner.toJson());
    remote.accounts['charlie'] = PercAccount(
      username: 'charlie',
      passwordHash: '',
      salt: '',
      address: charlieAddr,
      passwordSet: false,
      balance: PercAmount.fromPerc(2),
    );

    runner.mergeNetworkAccountBalances(remote);
    runner.creditScenario(username: 'bob', percentChance: 20);

    final charlieReward = PercStaking.rewardForBalance(PercAmount.fromPerc(2));
    expect(runner.account('charlie')!.cumulativeStakingEarned, charlieReward);
  });

  test('login full sync reconciles staking via hub import', () async {
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
    expect(
      remote.account('staker')!.cumulativeStakingEarned,
      expectedReward,
    );

    hub.importPeerLedger(remote, expectedTipHash: PercChainTip.hash(remote));
    hub.ledger.login('staker', 'password123');
    expect(hub.ledger.calculateStakingOwed('staker'), expectedReward);
    hub.ledger.reconcileSessionStakingFromChain('staker', applyCredits: true);

    expect(
      hub.ledger.sessionAccount!.cumulativeStakingEarned,
      expectedReward,
    );
    expect(
      hub.ledger.sessionAccount!.transactions.any(
        (t) => t.kind == PercTxKind.stakingReward,
      ),
      isTrue,
    );
  });

  test('staking rewards confirm in one block', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'staker', percentChance: 10);
    ledger.account('staker')!.balance = PercAmount.fromPerc(1);
    ledger.creditScenario(username: 'bob', percentChance: 10);

    final reward = ledger
        .account('staker')!
        .transactions
        .firstWhere((t) => t.kind == PercTxKind.stakingReward);
    expect(
      reward.confirmations,
      PercChainConstants.stakingConfirmationsRequired,
    );
    expect(reward.isConfirmed, isTrue);
  });
}