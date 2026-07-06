import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_transfer_relay_ack.dart';
import 'package:evolve/perc/services/perc_transfer_relay_view.dart';
import 'helpers/send_relay_fixture.dart';

void _tallSeed(PercLedger seed) {
  seed.ensureTreasuryAccount();
  seed.setupTreasuryPassword('password12345');
  seed.networkGenesisRevision = 2;
  seed.launchBlockchain();
  seed.consumeBlockchainLaunchEvent();
  for (var i = 0; i < 3; i++) {
    seed.blocks.add(
      PercBlock(
        index: seed.blocks.length,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
        scenarioLabel: 'Seed scenario $i',
      ),
    );
  }
}

void main() {
  test('resolve returns same tx.id for canonical and relaySource queries', () {
    final built = SendRelayFixture.build();
    final relay = PercLedger.fromJson(built.ledger.toJson());

    final seed = PercLedger.empty();
    _tallSeed(seed);
    expect(relay.blockHeight, lessThan(seed.blockHeight));

    PercTransferRelayAck.acknowledgeRelayTransfers(seed, relay);

    final canonicalIndex = seed.blocks.length - 1;
    final byCanonical = PercTransferRelayView.resolve(seed, canonicalIndex);

    expect(byCanonical, isNotNull);
    expect(byCanonical!.matchedBy, RelayMatchKind.canonical);
    expect(byCanonical.canonicalIndex, canonicalIndex);
    expect(byCanonical.relaySourceBlockIndex, built.transferBlockIndex);
    expect(byCanonical.transferTx!.id, built.transferTxId);

    // Alias lookup when sender index is unoccupied on the taller seed ledger.
    final aliasLedger = PercLedger.empty();
    _tallSeed(aliasLedger);
    aliasLedger.blocks.add(
      PercBlock(
        index: aliasLedger.blocks.length,
        relaySourceBlockIndex: 99,
        timestamp: DateTime.now().toUtc(),
        transactions: [
          PercTransaction(
            id: built.transferTxId,
            kind: PercTxKind.transfer,
            amount: PercAmount.fromPerc(0.00000005),
            timestamp: DateTime.now().toUtc(),
            fromUsername: 'alice',
            toUsername: 'bob',
            blockIndex: aliasLedger.blocks.length,
          ),
        ],
        treasuryEmitted: PercAmount.zero,
      ),
    );
    final byAlias = PercTransferRelayView.resolve(aliasLedger, 99);
    expect(byAlias, isNotNull);
    expect(byAlias!.matchedBy, RelayMatchKind.relaySource);
    expect(byAlias.transferTx!.id, built.transferTxId);
  });

  test('transferMarkerAngle uses relaySourceBlockIndex for ring timing', () {
    final block = PercBlock(
      index: 9,
      relaySourceBlockIndex: 2,
      timestamp: DateTime.now().toUtc(),
      transactions: const [],
      treasuryEmitted: PercAmount.zero,
    );
    final micro = PercChainConstants.microblocksPerBlock;
    final fromSource = PercTransferRelayView.transferMarkerAngle(block, micro);
    final fromCanonical = PercTransferRelayView.transferMarkerAngle(
      PercBlock(
        index: 9,
        timestamp: block.timestamp,
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
      ),
      micro,
    );
    expect(fromSource, isNot(equals(fromCanonical)));
    expect(fromSource, closeTo(2 / micro, 1e-12));
  });
}