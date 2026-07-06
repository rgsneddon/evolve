import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/app_performance.dart';
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
  Timer? _receivePollTimer;
  bool _appInBackground = false;

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

  @visibleForTesting
  void setNetworkBlockHeightForTest(int height) {
    _networkBlockHeight = height;
  }

  @visibleForTesting
  void setSyncStateForTest(PercNetworkSyncState state) {
    _syncState = state;
  }

  @visibleForTesting
  void setSeedConnectedForTest(bool connected) {
    _seedConnected = connected;
    notifyListeners();
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
    _stopReceivePolling();
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

    if (!disableLiveNodesForTests) {
      await _connectToSeedNode(hub);
    }

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

    if (!disableLiveNodesForTests &&
        username != PercChainConstants.treasuryUsername) {
      final addr = hub.ledger.sessionAccount?.address;
      await _rendezvous.relayLedger(username: username, ledger: hub.ledger);
      if (addr != null && addr.isNotEmpty) {
        await _rendezvous.publishAddress(address: addr, username: username);
      }
      await _registerSessionOnSeed(hub, status);
    }
    await _syncWithRetries(hub);
    hub.ledger.refreshPendingInboundTransfers();
    await hub.commit();
    _startReceivePolling();
    notifyListeners();
  }

  Future<void> onSessionEnded([String? username]) async {
    final hub = _hub;
    final ended = username ?? _activeUsername;
    _activeUsername = null;
    _stopReceivePolling();
    if (!disableLiveNodesForTests && _serverOrCreate.supportsLiveServing) {
      await _serverOrCreate.stop();
    }
    if (!disableLiveNodesForTests &&
        ended != null &&
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

    if (!disableLiveNodesForTests) {
      await _connectToSeedNode(hub);
    }
    hub.ledger.refreshPendingInboundTransfers();
    await syncToNetworkHeight();

    final session = hub.ledger.sessionUsername;
    if (!disableLiveNodesForTests &&
        session != null &&
        session != PercChainConstants.treasuryUsername &&
        session != PercChainConstants.seedUsername) {
      _publicEndpoint ??= await _resolveAdvertisedEndpoint();
      final status = PercNetworkStatus.fromLedger(
        hub.ledger,
        revision: hub.revision,
        endpoint: _publicEndpoint,
      );
      await _rendezvous.relayLedger(username: session, ledger: hub.ledger);
      final addr = hub.ledger.sessionAccount?.address;
      if (addr != null && addr.isNotEmpty) {
        await _rendezvous.publishAddress(address: addr, username: session);
      }
      await _registerSessionOnSeed(hub, status);
    }

    hub.ledger.refreshPendingInboundTransfers();
    await gossipToPeers();
    notifyListeners();
  }

  Future<void> syncToNetworkHeight() async {
    final hub = _hub;
    if (hub == null) return;

    if (disableLiveNodesForTests) {
      _networkBlockHeight = _maxKnownHeight();
      _syncState = PercNetworkSyncState.synced;
      notifyListeners();
      return;
    }

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
    String? importAddress;

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
        importAddress = status.walletAddress;
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
      if (!imported && importAddress != null) {
        final relayed = await _rendezvous.fetchRelayedLedger(
          address: importAddress,
        );
        if (relayed != null) {
          hub.importPeerLedger(relayed, expectedTipHash: targetTip);
          imported = true;
        }
      }
      if (!imported && importUsername != null) {
        final relayed = await _rendezvous.fetchRelayedLedger(
          username: importUsername,
        );
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
    if (hub == null || disableLiveNodesForTests) return;
    final ledger = hub.ledger;
    final localEndpoint = nodeEndpoint;
    final session = ledger.sessionUsername;

    if (session != null) {
      final status = PercNetworkStatus.fromLedger(
        ledger,
        revision: hub.revision,
        endpoint: localEndpoint,
      );
      await _rendezvous.relayLedger(username: session, ledger: ledger);
      final addr = ledger.sessionAccount?.address;
      if (addr != null && addr.isNotEmpty) {
        await _rendezvous.publishAddress(address: addr, username: session);
      }
      await _registerSessionOnSeed(hub, status);
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

  /// Blocks commits only when the local chain is strictly behind the network.
  void requireSyncedForMutation() {
    final hub = _hub;
    if (hub == null) return;
    final localHeight = PercChainTip.height(hub.ledger);
    if (localHeight >= _networkBlockHeight) return;
    if (!isSyncedToNetwork) {
      throw StateError(
        'Wallet syncing to network block height $_networkBlockHeight — try again shortly',
      );
    }
  }

  /// Pulls network state and settles inbound PERC for the signed-in wallet.
  Future<void> pollForInboundTransfers() async {
    final hub = _hub;
    if (hub == null || _activeUsername == null) return;

    await _heartbeatSessionToSeed();

    final heightBefore = PercChainTip.height(hub.ledger);
    final pendingBefore = hub.ledger.pendingInboundFor(_activeUsername!).length;
    final balanceBefore = hub.ledger.sessionBalance;

    await syncToNetworkHeight();
    hub.ledger.refreshPendingInboundTransfers();

    final changed = PercChainTip.height(hub.ledger) != heightBefore ||
        hub.ledger.pendingInboundFor(_activeUsername!).length != pendingBefore ||
        hub.ledger.sessionBalance != balanceBefore;

    if (changed) {
      await hub.commitWithoutSessionPromotion(promoteSessionNode: true);
    }
    notifyListeners();
  }

  /// Slow network polling while the app is minimized or on another desktop.
  void setAppInBackground(bool inBackground) {
    if (_appInBackground == inBackground) return;
    _appInBackground = inBackground;
    if (_receivePollTimer != null) {
      _startReceivePolling();
    }
  }

  Duration get _receivePollInterval => _appInBackground
      ? AppPerformance.backgroundNetworkPoll
      : AppPerformance.foregroundNetworkPoll;

  void _startReceivePolling() {
    if (disableLiveNodesForTests || _activeUsername == null) return;
    _receivePollTimer?.cancel();
    _receivePollTimer = Timer.periodic(
      _receivePollInterval,
      (_) {
        pollForInboundTransfers();
      },
    );
  }

  void _stopReceivePolling() {
    _receivePollTimer?.cancel();
    _receivePollTimer = null;
  }

  bool isWalletOnlineOnNetwork(String username) {
    return _hub?.ledger.isWalletOnlineOnNetwork(username) ?? false;
  }

  /// Instant delivery only when the seed node sees the recipient address/user online.
  Future<bool> isRecipientOnlineOnSeed({
    required String username,
    required String address,
  }) async {
    final hub = _hub;
    if (hub == null) return false;

    if (disableLiveNodesForTests) {
      return hub.ledger.isWalletOnlineOnNetwork(username);
    }

    final online = await _rendezvous.fetchRecipientOnlineOnSeed(
      username: username,
      address: address,
    );

    final height = PercChainTip.height(hub.ledger);
    final tip = PercChainTip.hash(hub.ledger);
    if (online) {
      hub.ledger.setWalletOnline(
        username,
        blockHeight: height,
        tipHash: tip,
      );
    } else {
      hub.ledger.setWalletOffline(
        username,
        blockHeight: height,
        tipHash: tip,
      );
    }
    notifyListeners();
    return online;
  }

  Future<void> _heartbeatSessionToSeed() async {
    if (disableLiveNodesForTests) return;
    final hub = _hub;
    final session = _activeUsername;
    if (hub == null || session == null) return;
    if (session == PercChainConstants.treasuryUsername ||
        session == PercChainConstants.seedUsername) {
      return;
    }

    _publicEndpoint ??= await _resolveAdvertisedEndpoint();
    final status = PercNetworkStatus.fromLedger(
      hub.ledger,
      revision: hub.revision,
      endpoint: _publicEndpoint,
    );
    final addr = hub.ledger.sessionAccount?.address;
    if (addr != null && addr.isNotEmpty) {
      await _rendezvous.publishAddress(address: addr, username: session);
    }
    await _registerSessionOnSeed(hub, status);
  }

  Future<void> _registerSessionOnSeed(
    PercLedgerHub _hub,
    PercNetworkStatus status,
  ) async {
    if (status.endpoint == null || status.sessionUsername == null) return;
    await _rendezvous.register(status);
  }

  Future<void> _syncWithRetries(PercLedgerHub hub, {int attempts = 3}) async {
    for (var i = 0; i < attempts; i++) {
      await syncToNetworkHeight();
      if (isSyncedToNetwork || isConnectedToSeed == false) return;
      if (i < attempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
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

    local = await _discoverAccountOnNetwork(normalized);
    if (local != null) return local;

    return null;
  }

  Future<PercAccount?> _discoverAccountOnNetwork(String normalized) async {
    final hub = _hub;
    if (hub == null || disableLiveNodesForTests) return null;

    PercAccount? _localHit() => hub.ledger.accountForAddress(normalized);

    void _mergeRemote(PercLedger remote) =>
        hub.ledger.mergeDiscoverableAccounts(remote);

    PercAccount? _ensureFromRemote(PercLedger remote) {
      final acc = remote.accountForAddress(normalized);
      if (acc == null) return null;
      return hub.ledger.ensureRemoteAccount(
        username: acc.username,
        address: acc.address,
      );
    }

    final indexed = await _rendezvous.lookupAddress(normalized);
    if (indexed != null) {
      final hit = _localHit();
      if (hit != null) return hit;
      final relayed = await _rendezvous.fetchRelayedLedger(
        address: indexed.address,
      );
      if (relayed != null) {
        _mergeRemote(relayed);
        final remoteHit = _localHit() ?? _ensureFromRemote(relayed);
        if (remoteHit != null) return remoteHit;
      }
    }

    final base = await _rendezvous.baseUrl();
    if (base != null) {
      final seedLedger = await _client.fetchLedger(base);
      if (seedLedger != null) {
        _mergeRemote(seedLedger);
        final hit = _localHit() ?? _ensureFromRemote(seedLedger);
        if (hit != null) return hit;
      }
    }

    final peers = await _rendezvous.fetchPeers();
    for (final status in peers) {
      if (status.walletAddress == normalized) {
        final relayed = await _rendezvous.fetchRelayedLedger(
          address: normalized,
        );
        if (relayed != null) {
          _mergeRemote(relayed);
          final hit = _localHit() ?? _ensureFromRemote(relayed);
          if (hit != null) return hit;
        }
      }
    }

    for (final status in peers) {
      final username = status.sessionUsername;
      final address = status.walletAddress;

      if (address != null && address.isNotEmpty) {
        final relayed = await _rendezvous.fetchRelayedLedger(address: address);
        if (relayed != null) {
          _mergeRemote(relayed);
          final hit = _localHit() ?? _ensureFromRemote(relayed);
          if (hit != null) return hit;
        }
      } else if (username != null) {
        final relayed = await _rendezvous.fetchRelayedLedger(username: username);
        if (relayed != null) {
          _mergeRemote(relayed);
          final hit = _localHit() ?? _ensureFromRemote(relayed);
          if (hit != null) return hit;
        }
      }

      final endpoint = status.endpoint;
      if (endpoint != null && PercPublicEndpoint.isInternetEndpoint(endpoint)) {
        final remote = await _client.fetchLedger(endpoint);
        if (remote != null) {
          _mergeRemote(remote);
          final hit = _localHit() ?? _ensureFromRemote(remote);
          if (hit != null) return hit;
        }
      }
    }

    return _localHit();
  }

  List<PercPeerNode> get onlineNodes =>
      _hub?.ledger.onlineNetworkNodes ?? const [];

  /// Connects to the internet seed node on every sync (including app launch).
  Future<void> _connectToSeedNode(PercLedgerHub hub) async {
    if (disableLiveNodesForTests) return;
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
    hub.ledger.updatePeerFromStatus(seedStatus, online: true);
    _seedConnected = true;

    var remote = await _client.fetchLedger(base);
    remote ??= await _rendezvous.fetchRelayedLedger(username: seedUser);
    if (remote == null) return;

    final localHeight = PercChainTip.height(hub.ledger);
    final remoteHeight = PercChainTip.height(remote);
    final seedGenesis = remote.networkGenesisRevision;
    final mustResetGenesis =
        seedGenesis > hub.ledger.networkGenesisRevision ||
        (seedGenesis >= targetGenesis &&
            localHeight > remoteHeight &&
            remoteHeight == 0);

    if (mustResetGenesis) {
      hub.resetFromSeedLedger(remote, expectedTipHash: seedStatus.tipHash);
      return;
    }

    if (remoteHeight > localHeight) {
      hub.importPeerLedger(remote, expectedTipHash: seedStatus.tipHash);
    }
  }

  Future<String?> _resolveAdvertisedEndpoint() async {
    final port = PercChainConstants.defaultNodePort;
    if (disableLiveNodesForTests) {
      return _serverOrCreate.endpoint ?? 'http://127.0.0.1:$port';
    }

    final serverEndpoint = _serverOrCreate.endpoint;
    if (PercPublicEndpoint.isInternetEndpoint(serverEndpoint)) {
      return serverEndpoint;
    }

    final internet =
        await const PercPublicEndpoint().resolveInternetEndpoint(port: port);
    if (PercPublicEndpoint.isInternetEndpoint(internet)) {
      return internet;
    }

    // Web / NAT wallets have no public node port — heartbeat via the seed rendezvous.
    final seed = await _rendezvous.baseUrl();
    if (seed != null) return seed;

    return serverEndpoint ?? 'http://127.0.0.1:$port';
  }

  @visibleForTesting
  Future<String?> resolveAdvertisedEndpointForTest() =>
      _resolveAdvertisedEndpoint();

  Future<void> _mergeRendezvousPeers(PercLedger ledger) async {
    final peers = await _rendezvous.fetchPeers();
    for (final status in peers) {
      if (status.sessionUsername == null &&
          (status.walletAddress == null || status.walletAddress!.isEmpty)) {
        continue;
      }
      ledger.updatePeerFromStatus(
        status,
        online: status.isFreshOnSeedPeer,
      );
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
        ledger.updatePeerFromStatus(status, online: false);
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