import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_dynamic_emission.dart';
import 'package:evolve/perc/services/perc_faucet.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_staking.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('pool renewal allocation is 283 million PERC', () {
    expect(
      PercChainConstants.poolRenewalAllocation,
      PercAmount.fromPerc(283000000),
    );
    expect(PercChainConstants.infiniteContinuumSupply, isTrue);
    expect(PercChainConstants.confirmationsRequired, 1);
    expect(PercChainConstants.minimumTreasuryReserve.displayFixed8, '0.00000001');
  });

  test('treasury faucet payouts continue when manual sends are locked', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    final result = ledger.creditScenario(username: 'alice', percentChance: 25);
    expect(result.status.name, 'credited');
    expect(ledger.isTreasurySendLocked, isTrue);
    expect(
      ledger.account('alice')!.balance.isPositive,
      isTrue,
    );
  });

  test('scenario credit depletes treasury by credited reward amount', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');

    ledger.creditScenario(username: 'alice', percentChance: 10);
    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final treasuryAfterAlice = treasury.balance;
    ledger.account('alice')!.balance = PercAmount.zero;

    final result = ledger.creditScenario(username: 'bob', percentChance: 33);
    expect(result.status, PercFaucetCreditStatus.credited);
    final reward = result.reward!.total;

    expect(
      treasury.balance.microUnits,
      treasuryAfterAlice.microUnits - reward.microUnits,
    );
    expect(ledger.account('bob')!.balance, reward);
    expect(
      treasury.transactions.any(
        (tx) =>
            tx.kind == PercTxKind.scenarioReward &&
            tx.toUsername == 'bob' &&
            tx.amount == reward,
      ),
      isTrue,
    );
  });

  test('treasury reserve blocks scenario payout without wallet credit', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'bob', percentChance: 10);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final alice = ledger.account('alice')!;
    final reward = PercFaucet.computeScenarioReward(percentChance: 50).total;
    final regenFloor = PercDynamicEmission.regenerationThreshold(
      ledger.emissionContext,
    );
    final maxPayable = reward + PercChainConstants.minimumTreasuryReserve;
    final shortfall = maxPayable - PercAmount(1);
    treasury.balance = shortfall.microUnits > regenFloor.microUnits
        ? shortfall
        : regenFloor + PercAmount(1);
    expect(treasury.balance < maxPayable, isTrue);

    final treasuryBefore = treasury.balance;
    alice.balance = PercAmount.zero;

    final result = ledger.creditScenario(username: 'alice', percentChance: 50);
    expect(result.status, PercFaucetCreditStatus.treasuryEmpty);
    expect(treasury.balance, treasuryBefore);
    expect(alice.balance, PercAmount.zero);
  });

  test('users cannot send PERC to evolve_treasury manually', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 10);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final before = treasury.balance;

    expect(
      () => ledger.send(
        fromUsername: 'alice',
        toAddress: _addr(ledger, PercChainConstants.treasuryUsername),
        amount: PercAmount.fromPerc(0.00000010),
      ),
      throwsA(isA<StateError>()),
    );
    expect(treasury.balance, before);
    expect(ledger.pendingInboundFor(PercChainConstants.treasuryUsername), isEmpty);
  });

  test('resolveAccountByAddress omits evolve_treasury after launch', () async {
    PercLedgerHub.resetForTest();
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password123');
    final ledger = PercLedgerHub.instance.ledger;
    ledger.launchBlockchain();
    ledger.consumeBlockchainLaunchEvent();

    final treasuryAddr =
        ledger.account(PercChainConstants.treasuryUsername)!.address;
    expect(
      ledger.accountForAddress(treasuryAddr)?.username,
      PercChainConstants.treasuryUsername,
    );

    final resolved = await PercLedgerHub.instance.network
        .resolveAccountByAddress(treasuryAddr);
    expect(resolved, isNull);
  });

  test('wallet send to treasury raw address is rejected without resolve', () async {
    PercLedgerHub.resetForTest();
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password123');
    await wallet.register('alice', 'password123');
    final ledger = PercLedgerHub.instance.ledger;
    ledger.launchBlockchain();
    ledger.consumeBlockchainLaunchEvent();
    await wallet.creditScenario(outcomeScore: 50, memo: 'fund');

    final treasuryAddr =
        ledger.account(PercChainConstants.treasuryUsername)!.address;
    await wallet.send(toAddress: treasuryAddr, amountText: '0.00000001');

    expect(wallet.errorMessage, 'wallet_err_treasury_no_manual_funding');
    expect(
      ledger.pendingInboundFor(PercChainConstants.treasuryUsername),
      isEmpty,
    );
  });

  test('repairForAppUpgrade purges legacy pending inbound to treasury', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 10);

    final treasuryBefore =
        ledger.account(PercChainConstants.treasuryUsername)!.balance;
    ledger.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'legacy-treasury-pending',
        fromUsername: 'alice',
        toUsername: PercChainConstants.treasuryUsername,
        amount: PercAmount.fromPerc(0.00000010),
        fee: PercChainConstants.sendTransactionFee,
        sentAt: DateTime.now().toUtc(),
      ),
    );

    ledger.repairForAppUpgrade();

    expect(ledger.pendingInboundFor(PercChainConstants.treasuryUsername), isEmpty);
    expect(
      ledger.account(PercChainConstants.treasuryUsername)!.balance,
      treasuryBefore,
    );
  });

  test('microblock seal after genesis does not credit treasury', () {
    PercChainConstants.microblocksPerBlockOverride = 3;
    PercChainConstants.microblocksPerWardOverride = 3;
    addTearDown(() {
      PercChainConstants.microblocksPerBlockOverride = null;
      PercChainConstants.microblocksPerWardOverride = null;
    });

    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 25);
    expect(ledger.treasuryGenesisDone, isTrue);

    final mintedBefore = ledger.cumulativeTreasuryMinted;
    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final emissionsBefore = treasury.transactions
        .where((t) => t.kind == PercTxKind.treasuryEmission)
        .length;
    const input = ScenarioInput(posedQuestion: 'Fair usage');
    for (var i = 0; i < 3; i++) {
      ledger.recordMicroblock(input: input);
    }

    expect(ledger.cumulativeTreasuryMinted, mintedBefore);
    expect(
      treasury.transactions
          .where((t) => t.kind == PercTxKind.treasuryEmission)
          .length,
      emissionsBefore,
    );
  });

  test('gossip ingest does not fund evolve_treasury', () {
    final local = PercLedger.empty();
    _seedLedger(local);
    local.register('alice', 'password123');
    local.creditScenario(username: 'alice', percentChance: 10);

    final remote = PercLedger.empty();
    _seedLedger(remote);
    remote.register('carol', 'password123');
    remote.creditScenario(username: 'carol', percentChance: 10);

    final amount = PercAmount.fromPerc(0.00000010);
    final sentAt = DateTime.now().toUtc();
    remote.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'malicious-treasury-fund',
        fromUsername: 'carol',
        toUsername: PercChainConstants.treasuryUsername,
        amount: amount,
        fee: PercChainConstants.sendTransactionFee,
        sentAt: sentAt,
      ),
    );

    final treasuryBefore =
        local.account(PercChainConstants.treasuryUsername)!.balance;

    local.mergePendingInboundFromPeer(remote);
    local.settlePendingInboundOnActivity(
      PercChainConstants.treasuryUsername,
      now: sentAt,
    );

    expect(local.pendingInboundFor(PercChainConstants.treasuryUsername), isEmpty);
    expect(
      local.account(PercChainConstants.treasuryUsername)!.balance,
      treasuryBefore,
    );
  });

  test('treasury evolve_treasury cannot send manually after blockchain launch', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'bob', percentChance: 10);

    expect(ledger.isTreasurySendLocked, isTrue);

    expect(
      () => ledger.send(
        fromUsername: PercChainConstants.treasuryUsername,
        toAddress: _addr(ledger, 'bob'),
        amount: PercAmount.fromPerc(0.00000010),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('staking stops at 1 cent treasury reserve', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('staker', 'password123');
    ledger.register('runner', 'password123');
    ledger.creditScenario(username: 'staker', percentChance: 10);

    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    treasury.balance = PercChainConstants.minimumTreasuryReserve +
        PercStaking.rewardPerBlock;

    ledger.send(
      fromUsername: 'staker',
      toAddress: _addr(ledger, 'runner'),
      amount: PercAmount(1),
    );

    expect(
      treasury.balance,
      PercChainConstants.minimumTreasuryReserve,
    );
  });

  test('infinite continuum skips 283M pool renewal at 1 cent reserve', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');

    final alice = ledger.account('alice')!;
    final treasury = ledger.account(PercChainConstants.treasuryUsername)!;
    final past = DateTime.now().toUtc().subtract(PercChainConstants.faucetCooldown);
    alice.lastFaucetDrawAt = past;
    treasury.balance = PercChainConstants.minimumTreasuryReserve;
    ledger.treasuryGenesisDone = true;
    ledger.lastScenarioAt = past;

    ledger.creditScenario(username: 'alice', percentChance: 25);

    expect(ledger.treasuryCycle, 1);
    expect(ledger.blocks.any((b) => b.isGenesisRenewal), isFalse);
    expect(
      treasury.balance.microUnits,
      lessThan(PercChainConstants.poolRenewalAllocation.microUnits),
    );
  });

  test('transactions are fully confirmed with one block', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 10);

    final block = ledger.blocks.last;
    expect(block.isConfirmed, isTrue);
    expect(block.confirmations, 1);
    expect(
      block.transactions.every((t) => t.isConfirmed),
      isTrue,
    );
  });
}