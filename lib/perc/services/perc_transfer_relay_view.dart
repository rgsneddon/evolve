import '../models/perc_block.dart';
import '../models/perc_transaction.dart';
import 'perc_ledger.dart';

/// Dart mirror of `transfer_relay_view.js` — single read contract for relay blocks.
class PercTransferRelayView {
  PercTransferRelayView._();

  static PercTransaction? firstTransferTx(PercBlock block) {
    for (final tx in block.transactions) {
      if (tx.kind == PercTxKind.transfer) return tx;
    }
    return null;
  }

  static RelayBlockView? resolve(PercLedger ledger, int queriedIndex) {
    final blocks = ledger.blocks;
    if (queriedIndex < 0 || blocks.isEmpty) return null;

    PercBlock? block;
    var matchedBy = RelayMatchKind.canonical;

    for (final b in blocks) {
      if (b.index == queriedIndex) {
        block = b;
        break;
      }
    }
    if (block == null) {
      for (final b in blocks) {
        if (b.relaySourceBlockIndex == queriedIndex) {
          block = b;
          matchedBy = RelayMatchKind.relaySource;
          break;
        }
      }
    }
    if (block == null && queriedIndex < blocks.length) {
      final positional = blocks[queriedIndex];
      if (positional.index == queriedIndex) {
        block = positional;
        matchedBy = RelayMatchKind.positional;
      }
    }
    if (block == null) return null;

    return RelayBlockView(
      block: block,
      queriedIndex: queriedIndex,
      canonicalIndex: block.index,
      relaySourceBlockIndex: block.relaySourceBlockIndex,
      matchedBy: matchedBy,
      displayIndex:
          matchedBy == RelayMatchKind.relaySource ? queriedIndex : block.index,
      transferTx: firstTransferTx(block),
    );
  }

  /// Microblock ring fraction (0–1) using sender relay source when present.
  static double transferMarkerAngle(PercBlock block, int microblocksPerBlock) {
    if (microblocksPerBlock <= 0) return 0;
    final timingIndex = block.relaySourceBlockIndex ?? block.index;
    return (timingIndex % microblocksPerBlock) / microblocksPerBlock;
  }

  static List<double> transferMarkerAnglesForBlocks(
    List<PercBlock> blocks,
    int microblocksPerBlock,
  ) {
    final transferBlocks =
        blocks.where((b) => firstTransferTx(b) != null).toList(growable: false);
    return transferBlocks
        .map((b) => transferMarkerAngle(b, microblocksPerBlock))
        .toList(growable: false);
  }
}

enum RelayMatchKind { canonical, relaySource, positional }

class RelayBlockView {
  const RelayBlockView({
    required this.block,
    required this.queriedIndex,
    required this.canonicalIndex,
    required this.relaySourceBlockIndex,
    required this.matchedBy,
    required this.displayIndex,
    required this.transferTx,
  });

  final PercBlock block;
  final int queriedIndex;
  final int canonicalIndex;
  final int? relaySourceBlockIndex;
  final RelayMatchKind matchedBy;
  final int displayIndex;
  final PercTransaction? transferTx;
}