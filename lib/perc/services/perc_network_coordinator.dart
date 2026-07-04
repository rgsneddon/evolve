import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/perc_account.dart';
import '../models/perc_peer_node.dart';
import '../perc_chain_constants.dart';
import 'perc_chain_tip.dart';
import 'perc_ledger.dart';
import 'perc_ledger_hub.dart';
import 'perc_network_client.dart';
import 'perc_network_config.dart';
import 'perc_network_protocol.dart';
import 'perc_network_rendezvous.dart';
import 'perc_node_server.dart';
import 'perc_node_server_factory.dart';
import 'perc_auth.dart';
import 'perc_public_endpoint.dart';

/// Aligns every wallet to the same block height over the internet.
class PercNetworkCoordinator extends ChangeNotifier {
  PercNetworkCoordinator({
    PercNetworkClient? client,
    PercNodeServer? server,
    PercNetworkRendezvous? rendezvous,
  })  : _client = client ?? const PercNetworkClient(),
        _rendezvous = rendezvous ?? const PercNetworkRendezvous(),
        _serverOverride = server;

  final PercNetworkClient _client;
  final PercNetworkRendezvous _rendezvous;
  PercNodeServer? _serverOverride;
  PercNodeServer? _server;

  PercNodeServer get _serverOrCreate =>
      _serverOverride ?? (_server ??= createPercNodeServer());

  PercLedgerHub? _hub;
  PercNetworkSyncState _syncState = PercNetworkSyncState.idle;
  int _networkBlockHeight = 0;
  String? _activeUsername;
  String? _publicEndpoint;
  bool _seedConnected = false;

  PercNetworkSyncState get syncState => _syncState;
  bool get isConnectedToSeed => _seedConnected;
  int get networkBlockHeight => _networkBlockHeight;
  bool get isSyncedToNetwork =>
      _syncState == PercNetworkSyncState.synced &&
      _hub != null &&
      _hub!.ledger.blockHeight == _networkBlockHeight;
  String? get nodeEndpoint => _publicEndpoint ?? _serverOrCreate.endpoint;
  bool get isNodeServing => _serverOrCreate.isRunning;
  bool get usesInternetEndpoint =>
      PercPublicEndpoint.isInternetEndpoint(nodeEndpoint);

  @visibleForTesting
  static void resetForTest() {
    disableLiveNodesForTests = true;
    instance._detach();
  }

  static final PercNetworkCoordinator instance = PercNetworkCoordinator();

  /// Disabled in tests by default; enabled from [main] for production wallets.
  static bool disableLiveNodesForTests = true;

  Future<void> bind(PercLedgerHub hub) async {
    _hub = hub;
    hub.addListener(_onHubChanged);
    await syncToNetworkHeight();
  }

  void _detach() {
    _hub?.removeListener(_onHubChanged);
    _hub = null;
    _syncState = PercNetworkSyncState.idle;
    _networkBlockHeight = 0;
    _activeUsername = null;
    _publicEndpoint = null;
    _seedConnected = false;
    _server?.stop();
    _server = null;
    _serverOverride = null;
  }

  void _onHubChanged() {
    _networkBlockHeight = _maxKnownHeight();
    notifyListeners();
  }

  Future<void> onSessionStarted(String username) async {
    final hub = _hub;
    if (hub == null) return;
    _activeUsername = username;

    await _connectToSeedNode(hub);

    if (!disableLiveNodesForTests && _serverOrCreate.supportsLiveServing) {
      await _serverOrCreate.start(hub);
    }

    _publicEndpoint = await _resolveAdvertisedEndpoint();
    final status = PercNetworkStatus.fromLedger(
      hub.ledger,
      revision: hub.revision,
      endpoint: _publicEndpoint,
    );

    hub.ledger.setWalletOnline(
      username,
      endpoint: _publicEndpoint,
      blockHeight: PercChainTip.height(hub.ledger),
      tipHash: PercChainTip.hash(hub.ledger),
    );

    if (username != PercChainConstants.treasuryUsername) {
      await _rendezvous.register(status);
    }
    await syncToNetworkHeight();
    await hub.commit();
    notifyListeners();
  }

  Future<void> onSessionEnded([String? username]) async {
    final hub = _hub;
    final ended = username ?? _activeUsername;
    _activeUsername = null;
    if (!disableLiveNodesForTests && _serverOrCreate.supportsLiveServing) {
      await _serverOrCreate.stop();
    }
    if (ended != null &&
        ended != PercChainConstants.treasuryUsername &&
        ended != PercChainConstants.seedUsername) {
      await _rendezvous.unregister(ended);
    }
    _publicEndpoint = null;
    if (hub != null && ended != null) {
      hub.ledger.setWalletOffline(
        ended,
        blockHeight: PercChainTip.height(hub.ledger),
        tipHash: PercChainTip.hash(hub.ledger),
      );
      await hub.commitWithoutSessionPromotion();
    }
    notifyListeners();
  }

  /// Manual sync — pull from seed, merge peers, re-publish wallet, gossip chain.
  Future<void> forceSyncWalletToSeed() async {
    final hub = _hub;
    if (hub == null) return;

    _syncState = PercNetworkSyncState.syncing;
    notifyListeners();

    await _connectToSeedNode(hub);
    hub.ledger.refreshPendingInboundTransfers();
    await syncToNetworkHeight();

    final session = hub.ledger.sessionUsername;
    if (session != null &&
        session != PercChainConstants.treasuryUsername &&
        session != PercChainConstants.seedUsername) {
      _publicEndpoint ??= await _resolveAdvertisedEndpoint();
      await _rendezvous.register(
        PercNetworkStatus.fromLedger(
          hub.ledger,
          revision: hub.revision,
          endpoint: _publicEndpoint,
        ),
      );
      await _rendezvous.relayLedger(username: session, ledger: hub.ledger);
    }

    await gossipToPeers();
    notifyListeners();
  }

  Future<void> syncToNetworkHeight() async {
    final hub = _hub;
    if (hub == null) return;

    _syncState = PercNetworkSyncState.syncing;
    notifyListeners();

    await _connectToSeedNode(hub);

    hub.ledger.ensureNetworkNodes(
      blockHeight: PercChainTip.height(hub.ledger),
      tipHash: PercChainTip.hash(hub.ledger),
    );

    await _mergeRendezvousPeers(hub.ledger);

    final peerStatuses = await _collectPeerStatuses(hub.ledger);
    var targetHeight = PercChainTip.height(hub.ledger);
    String? targetTip;
    String? importEndpoint;
    String? importUsername;

    for (final status in peerStatuses) {
      if (status.evolutionaryChainId !=
          PercChainConstants.evolutionaryChainId) {
        continue;
      }
      if (status.blockHeight > targetHeight) {
        targetHeight = status.blockHeight;
        targetTip = status.tipHash;
        importEndpoint = status.endpoint;
        importUsername = status.sessionUsername;
      } else if (status.blockHeight == targetHeight && targetTip == null) {
        targetTip = status.tipHash;
      }
    }

    _networkBlockHeight = _maxKnownHeight(peerStatuses: peerStatuses);

    if (targetHeight > PercChainTip.height(hub.ledger)) {
      var imported = false;
      if (importEndpoint != null &&
          PercPublicEndpoint.isInternetEndpoint(importEndpoint)) {
        final remote = await _client.fetchLedger(importEndpoint);
        if (remote != null) {
          hub.importPeerLedger(remote, expectedTipHash: targetTip);
          imported = true;
        }
      }
      if (!imported && importUsername != null) {
        final relayed = await _rendezvous.fetchRelayedLedger(importUsername);
        if (relayed != null) {
          hub.importPeerLedger(relayed, expectedTipHash: targetTip);
          imported = true;
        }
      }
      if (imported) {
        _networkBlockHeight = PercChainTip.height(hub.ledger);
      }
    }

    final localTip = PercChainTip.hash(hub.ledger);
    final localHeight = PercChainTip.height(hub.ledger);
    if (localHeight == _networkBlockHeight) {
      final mismatch = peerStatuses.any(
        (s) =>
            s.blockHeight == localHeight &&
            s.tipHash.isNotEmpty &&
            s.tipHash != localTip,
      );
      _syncState = mismatch
          ? PercNetworkSyncState.heightMismatch
          : PercNetworkSyncState.synced;
    } else if (localHeight < _networkBlockHeight) {
      _syncState = PercNetworkSyncState.syncing;
    } else {
      _syncState = PercNetworkSyncState.synced;
      _networkBlockHeight = localHeight;
    }

    if (_activeUsername != null) {
      hub.ledger.setWalletOnline(
        _activeUsername!,
        endpoint: _publicEndpoint,
        blockHeight: localHeight,
        tipHash: localTip,
      );
    }

    notifyListeners();
  }

  Future<void> gossipToPeers() async {
    final hub = _hub;
    if (hub == null) return;
    final ledger = hub.ledger;
    final localEndpoint = nodeEndpoint;
    final session = ledger.sessionUsername;

    if (session != null) {
      await _rendezvous.relayLedger(username: session, ledger: ledger);
      await _rendezvous.register(
        PercNetworkStatus.fromLedger(
          ledger,
          revision: hub.revision,
          endpoint: localEndpoint,
        ),
      );
    }

    final gossipTargets = ledger.networkNodes.values
        .map((n) => n.endpoint)
        .whereType<String>()
        .where((e) => e != localEndpoint)
        .toSet();
    final internetTargets =
        gossipTargets.where(PercPublicEndpoint.isInternetEndpoint).toList();
    final targets =
        internetTargets.isNotEmpty ? internetTargets : gossipTargets.toList();

    for (final endpoint in targets) {
      final pushed = await _client.pushLedger(
        endpoint: endpoint,
        ledger: ledger,
      );
      if (!pushed) {
        String? peer;
        for (final node in ledger.networkNodes.values) {
          if (node.endpoint == endpoint) {
            peer = node.username;
            break;
          }
        }
        if (peer != null && peer != session) {
          await _rendezvous.relayLedger(username: peer, ledger: ledger);
        }
      }
    }
    await syncToNetworkHeight();
  }

  void requireSyncedForMutation() {
    if (!isSyncedToNetwork) {
      throw StateError(
        'Wallet syncing to network block height $_networkBlockHeight — try again shortly',
      );
    }
  }

  bool isWalletOnlineOnNetwork(String username) {
    return _hub?.ledger.isWalletOnlineOnNetwork(username) ?? false;
  }

  /// Resolves a PERC address to an account — local first, then network rendezvous.
  Future<PercAccount?> resolveAccountByAddress(String address) async {
    final hub = _hub;
    if (hub == null) return null;
    final normalized = PercAuth.normalizeAddress(address);
    if (PercAuth.validateAddress(normalized) != null) return null;

    var local = hub.ledger.accountForAddress(normalized);
    if (local != null) return local;

    await syncToNetworkHeight();
    local = hub.ledger.accountForAddress(normalized);
    if (local != null) return local;

    final indexed = await _rendezvous.lookupAddress(normalized);
    if (indexed != null) {
      return hub.ledger.ensureRemoteAccount(
        username: indexed.username,
        address: indexed.address,
      );
    }

    final peers = await _rendezvous.fetchPeers();
    for (final status in peers) {
      if (status.walletAddress == normalized && status.sessionUsername != null) {
        return hub.ledger.ensureRemoteAccount(
          username: status.sessionUsername!,
          address: normalized,
        );
      }
    }

    for (final status in peers) {
      final username = status.sessionUsername;
      if (username == null) continue;

      final relayed = await _rendezvous.fetchRelayedLedger(username);
      if (relayed != null) {
        final acc = relayed.accountForAddress(normalized);
        if (acc != null) {
          return hub.ledger.ensureRemoteAccount(
            username: acc.username,
            address: acc.address,
          );
        }
      }

      final endpoint = status.endpoint;
      if (endpoint != null && PercPublicEndpoint.isInternetEndpoint(endpoint)) {
        final remote = await _client.fetchLedger(endpoint);
        if (remote != null) {
          final acc = remote.accountForAddress(normalized);
          if (acc != null) {
            return hub.ledger.ensureRemoteAccount(
              username: acc.username,
              address: acc.address,
            );
          }
        }
      }
    }

    return null;
  }

  List<PercPeerNode> get onlineNodes =>
      _hub?.ledger.onlineNetworkNodes ?? const [];

  /// Connects to the internet seed node on every sync (including app launch).
  Future<void> _connectToSeedNode(PercLedgerHub hub) async {
    final base = await _rendezvous.baseUrl();
    if (base == null) {
      _seedConnected = false;
      return;
    }

    final config = await PercNetworkConfig.load();
    final seedUser = config.seedUsername.isNotEmpty
        ? config.seedUsername
        : PercChainConstants.seedUsername;

    var seedStatus = await _client.fetchStatus(base);
    if (seedStatus == null) {
      _seedConnected = false;
      return;
    }

    final targetGenesis = config.networkGenesisRevision;
    seedStatus = PercNetworkStatus(
      evolutionaryChainId: seedStatus.evolutionaryChainId,
      blockHeight: seedStatus.blockHeight,
      tipHash: seedStatus.tipHash,
      revision: seedStatus.revision,
      networkGenesisRevision: seedStatus.networkGenesisRevision >= targetGenesis
          ? seedStatus.networkGenesisRevision
          : targetGenesis,
      sessionUsername: seedStatus.sessionUsername ?? seedUser,
      endpoint: base,
    );
    hub.ledger.updatePeerFromStatus(seedStatus);
    _seedConnected = true;

    var remote = await _client.fetchLedger(base);
    remote ??= await _rendezvous.fetchRelayedLedger(seedUser);
    if (remote == null) return;

    final localHeight = PercChainTip.height(hub.ledger);
    final seedGenesis = remote.networkGenesisRevision;
    final mustResetGenesis =
        seedGenesis > hub.ledger.networkGenesisRevision ||
        (seedGenesis >= targetGenesis &&
            localHeight > seedStatus.blockHeight &&
            seedStatus.blockHeight == 0);

    if (mustResetGenesis) {
      hub.resetFromSeedLedger(remote, expectedTipHash: seedStatus.tipHash);
      return;
    }

    if (seedStatus.blockHeight > localHeight) {
      hub.importPeerLedger(remote, expectedTipHash: seedStatus.tipHash);
    }
  }

  Future<String?> _resolveAdvertisedEndpoint() async {
    final serverEndpoint = _serverOrCreate.endpoint;
    if (disableLiveNodesForTests) return serverEndpoint;
    if (PercPublicEndpoint.isInternetEndpoint(serverEndpoint)) {
      return serverEndpoint;
    }
    final port = PercChainConstants.defaultNodePort;
    final internet =
        await const PercPublicEndpoint().resolveInternetEndpoint(port: port);
    return internet ?? serverEndpoint;
  }

  Future<void> _mergeRendezvousPeers(PercLedger ledger) async {
    final peers = await _rendezvous.fetchPeers();
    for (final status in peers) {
      if (status.sessionUsername == null) continue;
      ledger.updatePeerFromStatus(status);
    }
  }

  Future<List<PercNetworkStatus>> _collectPeerStatuses(PercLedger ledger) async {
    final results = <PercNetworkStatus>[];
    final seen = <String>{};

    final endpoints = <String>{};
    for (final node in ledger.networkNodes.values) {
      final endpoint = node.endpoint;
      if (endpoint != null && endpoint.isNotEmpty) {
        endpoints.add(endpoint);
      }
    }

    final internetEndpoints =
        endpoints.where(PercPublicEndpoint.isInternetEndpoint).toList();
    final toProbe =
        internetEndpoints.isNotEmpty ? internetEndpoints : endpoints.toList();

    for (final endpoint in toProbe) {
      if (seen.contains(endpoint)) continue;
      seen.add(endpoint);
      final status = await _client.fetchStatus(endpoint);
      if (status != null) {
        results.add(status);
        ledger.updatePeerFromStatus(status);
      }
    }

    return results;
  }

  int _maxKnownHeight({List<PercNetworkStatus>? peerStatuses}) {
    final hub = _hub;
    if (hub == null) return 0;
    var maxHeight = PercChainTip.height(hub.ledger);
    for (final node in hub.ledger.networkNodes.values) {
      if (node.blockHeight > maxHeight) maxHeight = node.blockHeight;
    }
    for (final status in peerStatuses ?? const <PercNetworkStatus>[]) {
      if (status.blockHeight > maxHeight) maxHeight = status.blockHeight;
    }
    return maxHeight;
  }
}