import '../models/perc_amount.dart';
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

  static PercBlock _emptyBlockAtIndex(int index) => PercBlock(
        index: index,
        timestamp: DateTime.now().toUtc(),
        transactions: const [],
        treasuryEmitted: PercAmount.zero,
      );

  static void _ensureChainSlots(PercLedger canonical, int minLength) {
    while (canonical.blocks.length < minLength) {
      canonical.blocks.add(_emptyBlockAtIndex(canonical.blocks.length));
    }
  }

  static List<String> _transferIdsInBlock(PercBlock block) => block.transactions
      .where((tx) => tx.kind == PercTxKind.transfer)
      .map((tx) => tx.id)
      .toList(growable: false);

  static PercBlock _clonePreservingHeight(PercBlock block) {
    final sourceIndex = block.index;
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
            blockIndex: tx.kind == PercTxKind.transfer ? sourceIndex : tx.blockIndex,
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
      index: sourceIndex,
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

  static bool _mergeBlockAtSourceIndex(PercLedger canonical, PercBlock block) {
    final sourceIndex = block.index;
    _ensureChainSlots(canonical, sourceIndex + 1);

    final incomingIds = _transferIdsInBlock(block);
    final existing = canonical.blocks[sourceIndex];
    final cloned = _clonePreservingHeight(block);

    if (existing.transactions.isEmpty) {
      canonical.blocks[sourceIndex] = cloned;
      return true;
    }

    final existingTransferIds = _transferIdsInBlock(existing).toSet();
    if (incomingIds.any(existingTransferIds.contains)) return false;
    if (existingTransferIds.isNotEmpty) return false;

    final mergedTxs = [
      ...existing.transactions,
      ...cloned.transactions.where((tx) => tx.kind == PercTxKind.transfer),
    ];
    canonical.blocks[sourceIndex] = PercBlock(
      index: sourceIndex,
      timestamp: existing.timestamp,
      transactions: mergedTxs,
      treasuryEmitted: existing.treasuryEmitted,
      scenarioLabel: existing.scenarioLabel,
      triggerUsername: existing.triggerUsername ?? cloned.triggerUsername,
      treasuryCycle: existing.treasuryCycle,
      isGenesisRenewal: existing.isGenesisRenewal,
      confirmations: existing.confirmations,
      microblockSeal: existing.microblockSeal,
      chronofluxFingerprint:
          existing.chronofluxFingerprint ?? cloned.chronofluxFingerprint,
      microblocksSealed: existing.microblocksSealed,
    );
    return true;
  }

  /// Promotes relay transfer blocks at the sender's block height.
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
      if (transferIds.any(known.contains)) continue;

      final sourceIndex = block.index;
      if (!_mergeBlockAtSourceIndex(canonical, block)) continue;

      for (final id in transferIds) {
        known.add(id);
        promoted.add(id);
      }
      canonicalIndices.add(sourceIndex);
      acknowledged += 1;
    }

    return RelayAckResult(
      acknowledged: acknowledged,
      transferIds: promoted,
      canonicalIndices: canonicalIndices,
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