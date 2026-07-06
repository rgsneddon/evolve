import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_account.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_pending_inbound_transfer.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  test('newer local chain merges pending from older peer app version', () {
    final newer = PercLedger.empty();
    newer.ensureTreasuryAccount();
    newer.setupTreasuryPassword('password12345');
    newer.launchBlockchain();
    newer.register('alice', 'password12345');
    newer.connectedAppVersion = '3.4.0+107';
    newer.creditScenario(username: 'alice', percentChance: 80, scenarioLabel: 'v3.4');
    final heightBefore = newer.blockHeight;
    newer.blocks.add(
      PercBlock(
        index: newer.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
      ),
    );
    expect(newer.blockHeight, greaterThan(heightBefore));

    final older = PercLedger.fromJson(newer.toJson());
    older.blocks.removeRange(1, older.blocks.length);
    older.connectedAppVersion = '3.3.11+83';
    older.evolvedAppVersions = ['3.3.11+83'];
    older.pendingInboundTransfers.add(
      PercPendingInboundTransfer(
        id: 'tx-cross-1',
        fromUsername: 'bob',
        toUsername: 'GLAL7',
        amount: PercAmount.smallestUnit,
        sentAt: DateTime.now().toUtc(),
      ),
    );
    older.accounts.clear();
    older.accounts['GLAL7'] = PercAccount(
      username: 'GLAL7',
      passwordHash: '',
      salt: 'salt',
      address: newer.account('alice')!.address,
      passwordSet: false,
      balance: PercAmount.zero,
      transactions: [],
    );

    newer.mergeNetworkStateFromPeer(older);

    expect(newer.pendingInboundFor('alice'), hasLength(1));
    expect(newer.pendingInboundFor('alice').first.id, 'tx-cross-1');
  });

  test('newer local chain merges transfer block from older peer app version', () {
    final newer = PercLedger.empty();
    newer.ensureTreasuryAccount();
    newer.setupTreasuryPassword('password12345');
    newer.launchBlockchain();
    newer.register('alice', 'password12345');
    newer.connectedAppVersion = '3.4.0+107';
    newer.creditScenario(username: 'alice', percentChance: 70, scenarioLabel: 'ahead');
    newer.blocks.add(
      PercBlock(
        index: newer.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
      ),
    );

    final aliceAddr = newer.account('alice')!.address;
    final sentAt = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    final older = PercLedger.empty();
    older.ensureTreasuryAccount();
    older.setupTreasuryPassword('password12345');
    older.launchBlockchain();
    older.connectedAppVersion = '3.3.11+83';
    older.accounts['GLAL7'] = PercAccount(
      username: 'GLAL7',
      passwordHash: '',
      salt: 'salt',
      address: aliceAddr,
      passwordSet: false,
      balance: PercAmount.zero,
      transactions: [],
    );
    older.blocks.add(
      PercBlock(
        index: 1,
        timestamp: sentAt,
        transactions: [
          PercTransaction(
            id: 'tx-cross-transfer',
            kind: PercTxKind.transfer,
            amount: PercAmount.smallestUnit,
            timestamp: sentAt,
            fromUsername: 'sender',
            toUsername: 'GLAL7',
            blockIndex: 1,
            confirmations: 1,
          ),
        ],
        treasuryEmitted: PercAmount.zero,
        triggerUsername: 'sender',
      ),
    );

    expect(newer.blockHeight, greaterThan(older.blockHeight));

    newer.mergeNetworkStateFromPeer(older);
    final pending = newer.pendingInboundFor('alice');
    expect(pending, hasLength(1));
    expect(pending.first.amount, PercAmount.smallestUnit);
    expect(pending.first.id, 'tx-cross-transfer');

    final balanceBefore = newer.account('alice')!.balance;
    newer.login('alice', 'password12345');

    expect(newer.pendingInboundFor('alice'), isEmpty);
    expect(
      newer.account('alice')!.balance.microUnits,
      greaterThan(balanceBefore.microUnits),
    );
  });
}