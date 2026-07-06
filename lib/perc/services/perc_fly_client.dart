import '../perc_chain_constants.dart';
import 'perc_chain_tip.dart';
import 'perc_ledger.dart';
import 'perc_network_protocol.dart';

/// Lightweight Perccent sync — probe chain tip via `/perc/status` first and
/// pull the full ledger only when the local wallet is behind or must reset.
class PercFlyClient {
  const PercFlyClient();

  /// True when a full `/perc/ledger` fetch is required before mutating chain state.
  bool needsFullLedger({
    required PercLedger local,
    required PercNetworkStatus seedStatus,
    required int targetGenesis,
  }) {
    final localHeight = PercChainTip.height(local);
    final remoteHeight = seedStatus.blockHeight;
    final seedGenesis = seedStatus.networkGenesisRevision >= targetGenesis
        ? seedStatus.networkGenesisRevision
        : targetGenesis;

    if (seedGenesis > local.networkGenesisRevision) return true;
    if (seedGenesis >= targetGenesis &&
        localHeight > remoteHeight &&
        remoteHeight == 0) {
      return true;
    }
    if (remoteHeight > localHeight) return true;

    if (remoteHeight == localHeight && remoteHeight > 0) {
      final localTip = PercChainTip.hash(local);
      final remoteTip = seedStatus.tipHash;
      if (remoteTip.isNotEmpty &&
          localTip.isNotEmpty &&
          remoteTip != localTip) {
        return true;
      }
    }

    return local.blocks.isEmpty && remoteHeight > 0;
  }

  /// Network height after a status-only probe (no ledger download).
  int networkHeightAfterProbe({
    required PercLedger local,
    required PercNetworkStatus seedStatus,
    Iterable<PercNetworkStatus> peerStatuses = const [],
  }) {
    var maxHeight = seedStatus.blockHeight;
    final localHeight = PercChainTip.height(local);
    if (localHeight > maxHeight) maxHeight = localHeight;
    for (final node in local.networkNodes.values) {
      if (node.blockHeight > maxHeight) maxHeight = node.blockHeight;
    }
    for (final status in peerStatuses) {
      if (status.blockHeight > maxHeight) maxHeight = status.blockHeight;
    }
    return maxHeight;
  }

  /// Sync state after tip-only alignment (wallet may still be catching up blocks).
  PercNetworkSyncState syncStateAfterQuickProbe({
    required PercLedger local,
    required int networkHeight,
    Iterable<PercNetworkStatus> peerStatuses = const [],
  }) {
    final localHeight = PercChainTip.height(local);
    final localTip = PercChainTip.hash(local);

    if (localHeight == networkHeight) {
      final mismatch = peerStatuses.any(
        (s) =>
            s.blockHeight == localHeight &&
            s.tipHash.isNotEmpty &&
            s.tipHash != localTip,
      );
      return mismatch
          ? PercNetworkSyncState.heightMismatch
          : PercNetworkSyncState.synced;
    }
    if (localHeight < networkHeight) {
      return PercNetworkSyncState.syncing;
    }
    return PercNetworkSyncState.synced;
  }

  PercNetworkStatus normalizeSeedStatus(
    PercNetworkStatus seedStatus, {
    required String seedUser,
    required String baseEndpoint,
    required int targetGenesis,
  }) {
    return PercNetworkStatus(
      evolutionaryChainId: seedStatus.evolutionaryChainId.isEmpty
          ? PercChainConstants.evolutionaryChainId
          : seedStatus.evolutionaryChainId,
      blockHeight: seedStatus.blockHeight,
      tipHash: seedStatus.tipHash,
      revision: seedStatus.revision,
      networkGenesisRevision: seedStatus.networkGenesisRevision >= targetGenesis
          ? seedStatus.networkGenesisRevision
          : targetGenesis,
      sessionUsername: seedStatus.sessionUsername ?? seedUser,
      endpoint: baseEndpoint,
      updatedAt: seedStatus.updatedAt,
    );
  }
}