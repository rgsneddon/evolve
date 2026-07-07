import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_account.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
  });

  test('ensureRemoteAccount allows send to QR-scanned cross-device address', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.launchBlockchain();
    ledger.register('sender', 'password12345');
    ledger.login('sender', 'password12345');
    ledger.creditScenario(
      username: 'sender',
      percentChance: 50,
      scenarioLabel: 'fund',
    );

    final receiverAddr = PercAuth.deriveAddress('receiver', 'remote-salt');
    ledger.ensureRemoteAccount(username: 'receiver', address: receiverAddr);

    expect(ledger.accountForAddress(receiverAddr)?.username, 'receiver');

    final tx = ledger.send(
      fromUsername: 'sender',
      toAddress: receiverAddr,
      amount: PercAmount.smallestUnit,
    );
    expect(tx.toUsername, 'receiver');
    expect(ledger.pendingInboundTransfers.length, 1);
  });

  test('local ledger without remote stub rejects unknown address', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.launchBlockchain();
    ledger.register('sender', 'password12345');
    ledger.login('sender', 'password12345');
    ledger.creditScenario(
      username: 'sender',
      percentChance: 50,
      scenarioLabel: 'fund',
    );

    final unknown = PercAuth.deriveAddress('elsewhere', 'other-salt');
    expect(
      () => ledger.send(
        fromUsername: 'sender',
        toAddress: unknown,
        amount: PercAmount.smallestUnit,
      ),
      throwsStateError,
    );
  });

  test('restoring local wallet remaps privacy alias transfers to real username', () {
    final local = PercLedger.empty();
    local.ensureTreasuryAccount();
    local.setupTreasuryPassword('password12345');
    local.launchBlockchain();
    local.register('alice', 'password12345');
    final aliceAddr = local.account('alice')!.address;

    final remote = PercLedger.fromJson(local.toJson());
    remote.accounts.clear();
    remote.accounts['GLAL7'] = PercAccount(
      username: 'GLAL7',
      passwordHash: '',
      salt: 'remote-salt',
      address: aliceAddr,
      passwordSet: false,
      balance: PercAmount.fromPerc(0.5),
      transactions: [],
    );
    remote.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'pending-1',
        fromUsername: 'bob',
        toUsername: 'GLAL7',
        amount: PercAmount.smallestUnit,
        sentAt: DateTime.now().toUtc(),
      ),
    );
    remote.blocks.add(
      PercBlock(
        index: remote.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
      ),
    );

    local.importPeerLedger(remote);

    expect(local.account('alice'), isNotNull);
    expect(local.account('GLAL7'), isNull);
    expect(local.pendingInboundFor('alice'), hasLength(1));
  });

  test('mergeDiscoverableAccounts stubs wallets from peer ledger', () {
    final local = PercLedger.empty();
    local.ensureTreasuryAccount();
    local.setupTreasuryPassword('password12345');
    local.launchBlockchain();
    local.register('sender', 'password12345');

    final remote = PercLedger.fromJson(local.toJson());
    remote.register('receiver', 'password12345');

    expect(local.accountForAddress(remote.account('receiver')!.address), isNull);

    local.mergeDiscoverableAccounts(remote);

    final receiverAddr = remote.account('receiver')!.address;
    expect(local.accountForAddress(receiverAddr)?.username, 'receiver');
    expect(local.account('receiver')?.passwordSet, isFalse);
  });

  test('wallet send resolves remote stub before ledger transfer', () async {
    final store = PercWalletStoreMemory();
    final wallet = PercWalletProvider(store: store);
    await wallet.initialize();
    await wallet.setupTreasuryPassword('password12345');
    await wallet.register('alice', 'password12345');
    PercLedgerHub.instance.ledger.launchBlockchain();
    final credit = await wallet.creditScenario(outcomeScore: 80, memo: 'fund');
    expect(credit, isNotNull);

    final bobAddr = PercAuth.deriveAddress('bob', 'bob-salt');
    PercLedgerHub.instance.ledger.ensureRemoteAccount(
      username: 'bob',
      address: bobAddr,
    );

    await wallet.send(toAddress: bobAddr, amountText: '0.00000001');
    expect(wallet.errorMessage, isNull);
    expect(wallet.statusMessage, 'wallet_status_sent_pending');
    expect(
      PercLedgerHub.instance.ledger.pendingInboundTransfers
          .any((p) => p.toUsername == 'bob'),
      isTrue,
    );
  });
}