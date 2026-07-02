import '../perc_chain_constants.dart';
import '../services/perc_ledger.dart';
import 'perc_block.dart';

/// Chronoflux microblock side chain — parented to the main Perccent chain.
class PercSideChainState {
  const PercSideChainState({
    required this.sideChainId,
    required this.parentChainId,
    required this.microblockHeight,
    required this.pendingMicroblocks,
    required this.microblocksPerBlock,
    this.lastSealMainBlockIndex,
    this.lastChronofluxFingerprint,
    this.parentMainBlockHeight = 0,
  });

  final String sideChainId;
  final String parentChainId;
  final int microblockHeight;
  final int pendingMicroblocks;
  final int microblocksPerBlock;
  final int? lastSealMainBlockIndex;
  final String? lastChronofluxFingerprint;
  final int parentMainBlockHeight;

  double get sealProgress =>
      microblocksPerBlock > 0 ? pendingMicroblocks / microblocksPerBlock : 0;

  factory PercSideChainState.fromLedger(PercLedger ledger) {
    PercBlock? lastSeal;
    for (var i = ledger.blocks.length - 1; i >= 0; i--) {
      if (ledger.blocks[i].microblockSeal) {
        lastSeal = ledger.blocks[i];
        break;
      }
    }
    return PercSideChainState(
      sideChainId: PercChainConstants.sideChainId,
      parentChainId: PercChainConstants.chainId,
      microblockHeight: ledger.totalMicroblocks,
      pendingMicroblocks: ledger.microblockCount,
      microblocksPerBlock: ledger.microblocksPerBlock,
      lastSealMainBlockIndex: lastSeal?.index,
      lastChronofluxFingerprint: ledger.lastChronofluxFingerprint,
      parentMainBlockHeight: ledger.blockHeight,
    );
  }
}