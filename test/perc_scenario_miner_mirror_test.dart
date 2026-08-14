import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_account.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_faucet.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/scenario_mirror_payout.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('miner running: every user gets the initiator faucet amount', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    final aliceBefore = ledger.account('alice')!.balance;
    final bobBefore = ledger.account('bob')!.balance;

    final expected = PercFaucet.computeScenarioReward(percentChance: 10).total;
    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      scenarioLabel: 'Percent chance: unrest near-term?',
      minerBook: const [
        {'connected': true, 'username': 'rig.raskul'},
      ],
    );

    expect(result.status, PercFaucetCreditStatus.credited);
    expect(result.reward!.total, expected);
    expect(result.reward!.outcomeFractionLabel, '10/100');
    expect(ledger.account('alice')!.balance, aliceBefore + expected);
    expect(ledger.account('bob')!.balance, bobBefore + expected);
    expect(ledger.account('alice')!.balance, ledger.account('bob')!.balance);
    expect(
      ledger.treasuryBalance,
      PercChainConstants.treasuryLaunchAllocation - expected * 2,
    );
  });

  test('miner not running: only initiator is credited', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    final aliceBefore = ledger.account('alice')!.balance;
    final bobBefore = ledger.account('bob')!.balance;

    final expected = PercFaucet.computeScenarioReward(percentChance: 10).total;
    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      scenarioLabel: 'Percent chance: unrest near-term?',
      minerBook: const [],
    );

    expect(result.status, PercFaucetCreditStatus.credited);
    expect(result.reward!.total, expected);
    expect(ledger.account('alice')!.balance, aliceBefore + expected);
    expect(ledger.account('bob')!.balance, bobBefore);
    expect(ledger.account('bob')!.balance, PercAmount.zero);
  });

  test('social cohesion kind uses the same miner-gated equal pay', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('alice', 'password123');
    ledger.register('carol', 'password123');

    final expected = PercFaucet.computeAnalysisReward(outcomeScore: 20).total;
    final on = ledger.creditScenario(
      username: 'alice',
      percentChance: 20,
      scenarioLabel: 'Social cohesion score: Glasgow ward cohesion',
      minerRunning: true,
    );
    expect(on.status, PercFaucetCreditStatus.credited);
    expect(on.reward!.total, expected);
    expect(on.reward!.outcomeFractionLabel, '20/100');
    expect(ledger.account('alice')!.balance, expected);
    expect(ledger.account('carol')!.balance, expected);

    final ledgerOff = PercLedger.empty();
    _seed(ledgerOff);
    ledgerOff.register('alice', 'password123');
    ledgerOff.register('carol', 'password123');
    final off = ledgerOff.creditScenario(
      username: 'alice',
      percentChance: 20,
      scenarioLabel: 'Social cohesion score: Glasgow ward cohesion',
      minerRunning: false,
    );
    expect(off.status, PercFaucetCreditStatus.credited);
    expect(ledgerOff.account('alice')!.balance, expected);
    expect(ledgerOff.account('carol')!.balance, PercAmount.zero);
  });

  test('live pool /api/stats book pays users and the pool miner the same unit', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
    final book = minerBookFromPoolStats({
      'ok': true,
      'minersOnline': 1,
      'workers': [
        {
          'wallet': miner,
          'connected': true,
          'hashrate': 8300,
        },
      ],
    });
    final expected = PercFaucet.computeScenarioReward(percentChance: 10).total;
    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      scenarioLabel: 'Percent chance: unrest near-term?',
      minerBook: book,
    );
    expect(result.status, PercFaucetCreditStatus.credited);
    expect(result.reward!.total, expected);
    expect(ledger.account('alice')!.balance, expected);
    expect(ledger.account('bob')!.balance, expected);
    expect(ledger.account(miner)!.balance, expected);
    expect(
      ledger.account(miner)!.transactions.first.kind,
      PercTxKind.minerReward,
    );
    expect(
      ledger.account('alice')!.transactions.first.kind,
      PercTxKind.scenarioReward,
    );
    expect(
      ledger.treasuryBalance,
      PercChainConstants.treasuryLaunchAllocation - expected * 3,
    );
  });

  test('empty offline miner book still pays configured pool miner the same unit', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('alice', 'password123');
    const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
    final expected = PercFaucet.computeScenarioReward(percentChance: 10).total;
    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      minerBook: const [],
      extraMiners: const [miner],
    );
    expect(result.status, PercFaucetCreditStatus.credited);
    expect(result.reward!.total.microUnits, expected.microUnits);
    expect(ledger.account('alice')!.balance.microUnits, expected.microUnits);
    expect(ledger.account(miner)!.balance.microUnits, expected.microUnits);
    expect(
      ledger.account(miner)!.transactions.any((tx) => tx.kind == PercTxKind.minerReward),
      isTrue,
    );
  });

  test('pool miner address credits existing XbghQ wallet not a new stub', () {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('alice', 'password123');
    ledger.register('XbghQ', 'password123');
    const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
    final old = ledger.account('XbghQ')!;
    ledger.accounts['XbghQ'] = PercAccount(
      username: old.username,
      passwordHash: old.passwordHash,
      salt: old.salt,
      address: miner,
      passwordSet: old.passwordSet,
      balance: old.balance,
      lastFaucetDrawAt: old.lastFaucetDrawAt,
      cumulativeStakingEarned: old.cumulativeStakingEarned,
      scenarioBlockHeight: old.scenarioBlockHeight,
      transactions: old.transactions,
    );
    final before = ledger.account('XbghQ')!.balance;
    final expected = PercFaucet.computeScenarioReward(percentChance: 10).total;
    final result = ledger.creditScenario(
      username: 'alice',
      percentChance: 10,
      minerBook: const [],
      extraMiners: const [miner],
    );
    expect(result.status, PercFaucetCreditStatus.credited);
    expect(ledger.account('XbghQ')!.balance.microUnits, (before + expected).microUnits);
    expect(ledger.account(miner), isNull);
    expect(
      ledger.account('XbghQ')!.transactions.any((tx) => tx.kind == PercTxKind.minerReward),
      isTrue,
    );
  });

  test('behind local ledger imports seed tip and keeps user plus miner rewards', () {
    final seed = PercLedger.empty();
    _seed(seed);
    seed.register('alice', 'password123');
    seed.register('bob', 'password123');
    const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
    final expected = PercFaucet.computeScenarioReward(percentChance: 10).total;
    seed.creditScenario(
      username: 'alice',
      percentChance: 10,
      minerBook: const [
        {'connected': true, 'wallet': miner},
      ],
    );

    final local = PercLedger.empty();
    _seed(local);
    local.register('alice', 'password123');
    expect(local.blockHeight, lessThan(seed.blockHeight));

    local.importPeerLedger(
      seed,
      expectedTipHash: PercChainTip.hash(seed),
    );

    expect(local.blockHeight, seed.blockHeight);
    expect(PercChainTip.hash(local), PercChainTip.hash(seed));
    expect(
      local.account('alice')!.balance.microUnits,
      expected.microUnits,
      reason:
          'alice=${local.account('alice')!.balance.microUnits} '
          'bob=${local.account('bob')?.balance.microUnits} '
          'miner=${local.account(miner)?.balance.microUnits} '
          'seedAlice=${seed.account('alice')!.balance.microUnits} '
          'seedBob=${seed.account('bob')!.balance.microUnits} '
          'expected=${expected.microUnits}',
    );
    expect(local.account('bob')!.balance.microUnits, expected.microUnits);
    expect(local.account(miner)!.balance.microUnits, expected.microUnits);
  });

  test('miner book connected or recent hash is running; empty is not', () {
    expect(
      minerBookHasRunningMiner(const [
        {'connected': true},
      ]),
      isTrue,
    );
    final now = DateTime.utc(2026, 8, 14, 12);
    expect(
      minerBookHasRunningMiner(
        [
          {'connected': false, 'lastHashAt': now.millisecondsSinceEpoch},
        ],
        now: now,
      ),
      isTrue,
    );
    expect(minerBookHasRunningMiner(const []), isFalse);
    expect(
      minerBookHasRunningMiner(const [
        {'connected': false},
      ]),
      isFalse,
    );
  });
}
