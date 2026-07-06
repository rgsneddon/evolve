import '../models/perc_block.dart';
import '../models/perc_transaction.dart';
import 'perc_ledger.dart';

/// Canonical relay acknowledgment mirrored from `transfer_relay_ack.js`.
class PercTransferRelayAck {
  PercTransferRelayAck._();

  static Set<String> _collectTransferTxIds(PercLedger ledger) {
    final ids = <String>{};
    for (final block in ledger.blocks) {
      for (final tx in block.transactions) {
        if (tx.kind == PercTxKind.transfer) ids.add(tx.id);
      }
    }
    return ids;
  }

  static bool _blockHasTransfer(PercBlock block) =>
      block.transactions.any((tx) => tx.kind == PercTxKind.transfer);

  /// Promotes relay transfer blocks by stable [tx.id], re-indexing to the
  /// canonical chain tip for monotonic explorers and frame-flow markers.
  static RelayAckResult acknowledgeRelayTransfers(
    PercLedger canonical,
    PercLedger relay,
  ) {
    if (canonical.networkGenesisRevision != relay.networkGenesisRevision) {
      return const RelayAckResult(
        acknowledged: 0,
        transferIds: [],
        canonicalIndices: [],
      );
    }

    final known = _collectTransferTxIds(canonical);
    final promoted = <String>[];
    final canonicalIndices = <int>[];
    var acknowledged = 0;

    for (final block in relay.blocks) {
      if (!_blockHasTransfer(block)) continue;
      final transferIds = block.transactions
          .where((tx) => tx.kind == PercTxKind.transfer)
          .map((tx) => tx.id)
          .toList(growable: false);
      if (transferIds.isEmpty) continue;
      if (transferIds.every(known.contains)) continue;

      final canonicalIndex = canonical.blocks.length;
      canonical.blocks.add(_cloneForCanonicalTip(block, canonicalIndex));
      for (final id in transferIds) {
        known.add(id);
        promoted.add(id);
      }
      canonicalIndices.add(canonicalIndex);
      acknowledged += 1;
    }

    return RelayAckResult(
      acknowledged: acknowledged,
      transferIds: promoted,
      canonicalIndices: canonicalIndices,
    );
  }

  static PercBlock _cloneForCanonicalTip(PercBlock block, int canonicalIndex) {
    final txs = block.transactions
        .map(
          (tx) => PercTransaction(
            id: tx.id,
            kind: tx.kind,
            amount: tx.amount,
            timestamp: tx.timestamp,
            fromUsername: tx.fromUsername,
            toUsername: tx.toUsername,
            memo: tx.memo,
            scenarioLabel: tx.scenarioLabel,
            percentChance: tx.percentChance,
            blockIndex: canonicalIndex,
            confirmations: tx.confirmations,
            chronofluxFingerprint: tx.chronofluxFingerprint,
            microblockIndex: tx.microblockIndex,
            continuumScs: tx.continuumScs,
            vortexScs: tx.vortexScs,
            shearScs: tx.shearScs,
            resistanceScs: tx.resistanceScs,
            flowScs: tx.flowScs,
          ),
        )
        .toList(growable: false);

    return PercBlock(
      index: canonicalIndex,
      timestamp: block.timestamp,
      transactions: txs,
      treasuryEmitted: block.treasuryEmitted,
      scenarioLabel: block.scenarioLabel,
      triggerUsername: block.triggerUsername,
      treasuryCycle: block.treasuryCycle,
      isGenesisRenewal: block.isGenesisRenewal,
      confirmations: block.confirmations,
      microblockSeal: block.microblockSeal,
      chronofluxFingerprint: block.chronofluxFingerprint,
      microblocksSealed: block.microblocksSealed,
    );
  }
}

class RelayAckResult {
  const RelayAckResult({
    required this.acknowledged,
    required this.transferIds,
    required this.canonicalIndices,
  });

  final int acknowledged;
  final List<String> transferIds;
  final List<int> canonicalIndices;

  bool get ok => acknowledged > 0;
}