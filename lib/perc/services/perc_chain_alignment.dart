import '../perc_chain_constants.dart';
import 'perc_chain_tip.dart';
import 'perc_ledger.dart';
import 'perc_network_protocol.dart';

/// Canonical chain coordinates taken from an imported seed ledger snapshot.
class SeedAlignmentTarget {
  const SeedAlignmentTarget({
    required this.chainId,
    required this.height,
    required this.tipHash,
  });

  final String chainId;
  final int height;
  final String tipHash;

  static SeedAlignmentTarget fromLedger(PercLedger ledger) => SeedAlignmentTarget(
        chainId: PercChainAlignment.effectiveChainId(ledger),
        height: PercChainTip.height(ledger),
        tipHash: PercChainTip.hash(ledger),
      );
}

/// Pure predicates for whether a local ledger matches the canonical seed chain.
class PercChainAlignment {
  const PercChainAlignment._();

  static String effectiveChainId(PercLedger ledger) =>
      ledger.evolutionaryChainId.isEmpty
          ? PercChainConstants.evolutionaryChainId
          : ledger.evolutionaryChainId;

  static bool chainIdsMatch({
    required PercLedger local,
    required String seedChainId,
  }) {
    final remoteId = seedChainId.isEmpty
        ? PercChainConstants.evolutionaryChainId
        : seedChainId;
    return effectiveChainId(local) == remoteId;
  }

  static bool isAlignedWithSeed({
    required PercLedger local,
    required String seedChainId,
    required int seedHeight,
    required String seedTipHash,
  }) {
    if (!chainIdsMatch(local: local, seedChainId: seedChainId)) return false;
    final localHeight = PercChainTip.height(local);
    if (localHeight != seedHeight) return false;
    if (seedTipHash.isEmpty) return true;
    return PercChainTip.hash(local) == seedTipHash;
  }

  static bool isAlignedWithStatus({
    required PercLedger local,
    required PercNetworkStatus seedStatus,
  }) =>
      isAlignedWithSeed(
        local: local,
        seedChainId: seedStatus.evolutionaryChainId,
        seedHeight: seedStatus.blockHeight,
        seedTipHash: seedStatus.tipHash,
      );

  static bool isBehindOrTipMismatch({
    required PercLedger local,
    required int seedHeight,
    required String seedTipHash,
  }) {
    final localHeight = PercChainTip.height(local);
    if (localHeight < seedHeight) return true;
    if (localHeight > seedHeight) return false;
    if (seedTipHash.isEmpty) return false;
    return PercChainTip.hash(local) != seedTipHash;
  }

  static PercNetworkSyncState syncStateForSeed({
    required PercLedger local,
    required int seedHeight,
    required String seedTipHash,
  }) {
    final localHeight = PercChainTip.height(local);
    if (localHeight < seedHeight) return PercNetworkSyncState.syncing;
    if (localHeight == seedHeight &&
        seedTipHash.isNotEmpty &&
        PercChainTip.hash(local) != seedTipHash) {
      return PercNetworkSyncState.heightMismatch;
    }
    return PercNetworkSyncState.synced;
  }
}

/// Outcome of adopting the internet seed chain during new-user registration.
class PercRegistrationSeedAdoption {
  const PercRegistrationSeedAdoption({
    required this.seedReachable,
    required this.isAligned,
    required this.seedHeight,
    required this.seedTipHash,
    required this.seedChainId,
  });

  final bool seedReachable;
  final bool isAligned;
  final int seedHeight;
  final String seedTipHash;
  final String seedChainId;
}