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

  /// Promotes relay transfer blocks by stable [tx.id], preserving sender
  /// block index, blockIndex, timestamps, and fingerprints.
  static RelayAckResult acknowledgeRelayTransfers(
    PercLedger canonical,
    PercLedger relay,
  ) {
    if (canonical.networkGenesisRevision != relay.networkGenesisRevision) {
      return const RelayAckResult(acknowledged: 0, transferIds: []);
    }

    final known = _collectTransferTxIds(canonical);
    final promoted = <String>[];
    var acknowledged = 0;

    for (final block in relay.blocks) {
      if (!_blockHasTransfer(block)) continue;
      final transferIds = block.transactions
          .where((tx) => tx.kind == PercTxKind.transfer)
          .map((tx) => tx.id)
          .toList(growable: false);
      if (transferIds.isEmpty) continue;
      if (transferIds.every(known.contains)) continue;

      canonical.blocks.add(_clonePreservedBlock(block));
      for (final id in transferIds) {
        known.add(id);
        promoted.add(id);
      }
      acknowledged += 1;
    }

    return RelayAckResult(
      acknowledged: acknowledged,
      transferIds: promoted,
    );
  }

  static PercBlock _clonePreservedBlock(PercBlock block) {
    final json = block.toJson();
    final txs = (json['transactions'] as List<dynamic>)
        .map((e) => PercTransaction.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return PercBlock.fromJson({...json, 'transactions': txs.map((t) => t.toJson()).toList()});
  }
}

class RelayAckResult {
  const RelayAckResult({
    required this.acknowledged,
    required this.transferIds,
  });

  final int acknowledged;
  final List<String> transferIds;

  bool get ok => acknowledged > 0;
}