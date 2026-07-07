import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_peer_node.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

String _addr(PercLedger ledger, String username) =>
    ledger.account(username)!.address;

void _seedLedger(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password123');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('send anchors at seed height while pending until scenario confirm', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    const seedHeight = 42;
    ledger.networkNodes = {
      PercChainConstants.seedUsername: PercPeerNode.offline(
        username: PercChainConstants.seedUsername,
        blockHeight: seedHeight,
        tipHash: 'seed-tip',
      ),
    };

    final localHeightBefore = ledger.blockHeight;
    expect(localHeightBefore, lessThan(seedHeight));

    final tx = ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000005),
      seedConfirmationBlockHeight: seedHeight,
    );

    expect(tx.isConfirmed, isFalse);
    expect(tx.blockIndex, seedHeight);
    expect(ledger.account('bob')!.balance, PercAmount.zero);
    expect(ledger.pendingInboundFor('bob'), hasLength(1));
    expect(
      ledger.account('bob')!.transactions.single.isConfirmed,
      isFalse,
    );
    expect(
      ledger.blocks.any((b) => b.transactions.any((t) => t.id == tx.id)),
      isTrue,
    );
  });

  test('receiver credits inbound only after scenario within receive window', () {
    final ledger = PercLedger.empty();
    _seedLedger(ledger);
    ledger.register('alice', 'password123');
    ledger.register('bob', 'password123');
    ledger.creditScenario(username: 'alice', percentChance: 50);

    ledger.send(
      fromUsername: 'alice',
      toAddress: _addr(ledger, 'bob'),
      amount: PercAmount.fromPerc(0.00000010),
    );

    ledger.login('bob', 'password123');
    expect(ledger.pendingInboundFor('bob'), hasLength(1));
    expect(ledger.account('bob')!.balance, PercAmount.zero);

    ledger.advanceScenarioBlock('bob');
    expect(ledger.pendingInboundFor('bob'), isEmpty);
    expect(
      ledger.account('bob')!.balance,
      PercAmount.fromPerc(0.00000010),
    );
    expect(
      ledger.account('bob')!.transactions.any(
            (tx) => tx.isConfirmed && tx.amount == PercAmount.fromPerc(0.00000010),
          ),
      isTrue,
    );
  });
}