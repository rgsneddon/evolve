import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/app_performance.dart';
import '../models/perc_account.dart';
import '../models/perc_peer_node.dart';
import '../perc_chain_constants.dart';
import 'perc_chain_alignment.dart';
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
import 'perc_fly_client.dart';
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
  final PercFlyClient _flyClient = const PercFlyClient();
  PercNodeServer? _serverOverride;
  PercNodeServer? _server;
  bool _deepSyncRunning = false;
  int _networkGeneration = 0;

  PercNodeServer get _serverOrCreate =>
      _serverOverride ?? (_server ??= createPercNodeServer());

  PercLedgerHub? _hub;
  PercNetworkSyncState _syncState = PercNetworkSyncState.idle;
  int _networkBlockHeight = 0;
  String? _activeUsername;
  String? _publicEndpoint;
  bool _seedConnected = false;
  Timer? _receivePollTimer;
  Timer? _burstPollTimer;
  int _burstAttemptsRemaining = 0;
  DateTime? _lastBurstStarted;
  final Set<String> _burstSenderTargets = {};
  Timer? _pendingRegistrationRetryTimer;
  bool _appInBackground = false;
  final Map<String, PercLedger> _senderPeerCache = {};

  /// In-memory sender ledgers for [propagateSettlementWitnesses] when live nodes
  /// are disabled (models HTTP push + sender ingest in integration tests).
  @visibleForTesting
  final Map<String, PercLedger> settlementPeerTargets = {};

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

  bool _isNetworkGenerationCurrent(int generation) =>
      generation == _networkGeneration;

  @visibleForTesting
  static void resetForTest() {
    instance._networkGeneration++;
    disableLiveNodesForTests = true;
    instance._senderPeerCache.clear();
    instance.settlementPeerTargets.clear();
    instance.clearTestSeedLedger();
    instance.clearPendingRegistrationRecovery();
    instance.onPendingRegistrationRecoveryReady = null;
    PercNetworkRendezvous.resetForTest();
    instance._detach();
  }

  @visibleForTesting
  int get burstAttemptsRemainingForTest => _burstAttemptsRemaining;

  @visibleForTesting
  bool get burstActiveForTest =>
      _burstPollTimer != null || _burstAttemptsRemaining > 0;

  @visibleForTesting
  void registerSenderPeerForTest(String username, PercLedger peer) {
    _senderPeerCache[username] = peer;
  }

  PercSenderPeerResolver get senderPeerResolver =>
      (fromUsername) => _senderPeerCache[fromUsername];

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

  /// Simulated internet seed ledger for registration-alignment harness tests.
  @visibleForTesting
  PercLedger? testSeedLedger;

  /// When false, registration adoption reports seed offline (honest sync-pending).
  @visibleForTesting
  bool testSeedReachable = true;

  @visibleForTesting
  void registerTestSeedLedger(PercLedger seed) {
    testSeedLedger = seed;
    testSeedReachable = true;
  }

  @visibleForTesting
  void clearTestSeedLedger() {
    testSeedLedger = null;
    testSeedReachable = true;
  }

  String? _pendingRegistrationUsername;
  String? _pendingRegistrationPassword;
  List<String>? _pendingRegistrationMnemonic;
  int _pendingSeedHeight = 0;
  String _pendingSeedTipHash = '';
  String _pendingSeedChainId = '';

  /// Invoked when pending registration becomes aligned after background sync.
  Future<bool> Function()? onPendingRegistrationRecoveryReady;

  @visibleForTesting
  String? get activeUsernameForTest => _activeUsername;

  @visibleForTesting
  String? get pendingRegistrationUsernameForTest => _pendingRegistrationUsername;

  @visibleForTesting
  String? get pendingRegistrationPasswordForTest => _pendingRegistrationPassword;

  bool get hasPendingRegistrationRecovery =>
      _pendingRegistrationUsername != null &&
      _pendingRegistrationPassword != null;

  void setPendingRegistrationRecovery({
    required String username,
    required String password,
    List<String>? seedMnemonic,
  }) {
    _pendingRegistrationUsername = PercAuth.normalizeUsername(username);
    _pendingRegistrationPassword = password;
    _pendingRegistrationMnemonic = seedMnemonic;
  }

  void clearPendingRegistrationRecovery() {
    _pendingRegistrationUsername = null;
    _pendingRegistrationPassword = null;
    _pendingRegistrationMnemonic = null;
    _pendingSeedHeight = 0;
    _pendingSeedTipHash = '';
    _pendingSeedChainId = '';
  }

  void _rememberPendingSeedTarget({
    required int seedHeight,
    required String seedTipHash,
    required String seedChainId,
  }) {
    _pendingSeedHeight = seedHeight;
    _pendingSeedTipHash = seedTipHash;
    _pendingSeedChainId = seedChainId;
  }

  bool isPendingRegistrationAligned(PercLedgerHub hub) {
    if (!hasPendingRegistrationRecovery) return false;
    if (!_seedConnected) return false;

    final username =
        _pendingRegistrationUsername ?? hub.ledger.sessionUsername;
    if (username == null) return false;
    if (hub.ledger.account(username) == null) return false;

    final target = _importedSeedTarget(hub);
    if (target == null) return false;
    return PercChainAlignment.isAlignedWithSeed(
      local: hub.ledger,
      seedChainId: target.chainId,
      seedHeight: target.height,
      seedTipHash: target.tipHash,
    );
  }

  /// Post-import seed snapshot — only valid after `_refreshSeedPeerFromLedger`.
  SeedAlignmentTarget? _importedSeedTarget(PercLedgerHub hub) {
    if (_pendingSeedTipHash.isEmpty || _pendingSeedHeight <= 0) return null;
    return SeedAlignmentTarget(
      chainId: _pendingSeedChainId.isNotEmpty
          ? _pendingSeedChainId
          : PercChainAlignment.effectiveChainId(hub.ledger),
      height: _pendingSeedHeight,
      tipHash: _pendingSeedTipHash,
    );
  }

  PercNetworkStatus _statusWithImportedSeedTip(
    PercNetworkStatus probe,
    PercLedgerHub hub,
  ) {
    final imported = _importedSeedTarget(hub);
    if (imported == null) {
      final localHeight = PercChainTip.height(hub.ledger);
      if (localHeight > 0 && localHeight >= probe.blockHeight) {
        return PercNetworkStatus(
          evolutionaryChainId: PercChainAlignment.effectiveChainId(hub.ledger),
          blockHeight: localHeight,
          tipHash: PercChainTip.hash(hub.ledger),
          revision: probe.revision,
          networkGenesisRevision: probe.networkGenesisRevision,
          sessionUsername: probe.sessionUsername,
          publicAlias: probe.publicAlias,
          endpoint: probe.endpoint,
          walletAddress: probe.walletAddress,
          updatedAt: probe.updatedAt,
        );
      }
      return probe;
    }
    return PercNetworkStatus(
      evolutionaryChainId: imported.chainId,
      blockHeight: imported.height,
      tipHash: imported.tipHash,
      revision: probe.revision,
      networkGenesisRevision: probe.networkGenesisRevision,
      sessionUsername: probe.sessionUsername,
      publicAlias: probe.publicAlias,
      endpoint: probe.endpoint,
      walletAddress: probe.walletAddress,
      updatedAt: probe.updatedAt,
    );
  }

  /// Syncs seed peer coordinates from the local ledger after commits.
  void refreshSeedPeerFromLocalLedger() {
    final hub = _hub;
    if (hub == null) return;
    _refreshSeedPeerFromLedger(hub, hub.ledger);
  }

  void _refreshSeedPeerFromLedger(
    PercLedgerHub hub,
    PercLedger remote, {
    PercNetworkStatus? seedStatus,
  }) {
    final target = SeedAlignmentTarget.fromLedger(hub.ledger);
    _networkBlockHeight = target.height;
    _rememberPendingSeedTarget(
      seedHeight: target.height,
      seedTipHash: target.tipHash,
      seedChainId: target.chainId,
    );

    final seedUser = PercChainConstants.seedUsername;
    final existing = hub.ledger.networkNodes[seedUser];
    hub.ledger.networkNodes[seedUser] = PercPeerNode(
      username: seedUser,
      endpoint: seedStatus?.endpoint ?? existing?.endpoint,
      blockHeight: target.height,
      tipHash: target.tipHash,
      online: seedStatus?.isFreshOnSeedPeer ?? existing?.online ?? _seedConnected,
      lastSeen:
          seedStatus?.updatedAt?.toUtc() ?? existing?.lastSeen ?? DateTime.now().toUtc(),
    );
  }

  /// Re-adopts the seed chain using credentials held for pending registration.
  Future<PercRegistrationSeedAdoption> adoptPendingRegistrationChain() async {
    final username = _pendingRegistrationUsername;
    final password = _pendingRegistrationPassword;
    if (username == null || password == null) {
      return const PercRegistrationSeedAdoption(
        seedReachable: false,
        isAligned: false,
        seedHeight: 0,
        seedTipHash: '',
        seedChainId: PercChainConstants.evolutionaryChainId,
      );
    }
    return adoptSeedChainForRegistration(
      username: username,
      password: password,
      seedMnemonic: _pendingRegistrationMnemonic,
    );
  }

  /// Publishes a pending registration once the local ledger matches the seed.
  Future<bool> completePendingRegistrationIfReady() async {
    final hub = _hub;
    if (hub == null) return false;
    if (!hasPendingRegistrationRecovery) return false;
    if (!isPendingRegistrationAligned(hub)) return false;

    final username = _pendingRegistrationUsername;
    if (username == null || hub.ledger.account(username) == null) {
      return false;
    }

    await onSessionStarted(username);
    await hub.commitAfterRegistrationPublish();
    clearPendingRegistrationRecovery();
    notifyListeners();
    return true;
  }

  Future<void> _maybeNotifyPendingRegistrationRecovery(
    PercLedgerHub hub,
  ) async {
    if (!hasPendingRegistrationRecovery) return;
    if (!isPendingRegistrationAligned(hub)) return;

    final handled = await onPendingRegistrationRecoveryReady?.call() ?? false;
    if (!handled) {
      await completePendingRegistrationIfReady();
    }
  }

  void _schedulePendingRegistrationDeepSyncRetry() {
    if (!hasPendingRegistrationRecovery) return;
    if (disableLiveNodesForTests) return;

    _pendingRegistrationRetryTimer?.cancel();
    _pendingRegistrationRetryTimer = Timer(const Duration(seconds: 3), () {
      _pendingRegistrationRetryTimer = null;
      if (hasPendingRegistrationRecovery) {
        scheduleDeepSync();
      }
    });
  }

  @visibleForTesting
  Future<void> awaitDeepSyncIdle({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_deepSyncRunning) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Timed out waiting for deep sync');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  void _applyTestSeedForPendingRegistration(PercLedgerHub hub) {
    if (!disableLiveNodesForTests) return;
    if (!hasPendingRegistrationRecovery) return;
    if (!testSeedReachable || testSeedLedger == null) return;

    final seed = PercLedger.fromJson(testSeedLedger!.toJson());
    final status = PercNetworkStatus.fromLedger(
      seed,
      revision: 1,
      endpoint: 'http://test-seed/perc',
    );
    _applySeedLedgerToHub(hub, seed, status);
    _networkBlockHeight = PercChainTip.height(seed);
    _syncState = PercNetworkSyncState.synced;
    _seedConnected = true;
  }

  static final PercNetworkCoordinator instance = PercNetworkCoordinator();

  /// Disabled in tests by default; enabled from [main] for production wallets.
  static bool disableLiveNodesForTests = true;

  Future<void> bind(PercLedgerHub hub) async {
    _hub = hub;
    hub.addListener(_onHubChanged);
    await quickSyncToNetworkHeight();
    scheduleDeepSync();
  }

  void _detach() {
    _networkGeneration++;
    _stopReceivePolling();
    _stopBurstPolling();
    _pendingRegistrationRetryTimer?.cancel();
    _pendingRegistrationRetryTimer = null;
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
      await _connectToSeedNode(hub, deep: false);
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
    _refreshSeedPeerFromLedger(hub, hub.ledger);
    hub.ledger.refreshPendingInboundTransfers();
    await hub.persistLocal();
    _startReceivePolling();
    notifyListeners();
    scheduleDeepSync();
  }

  /// Attaches a new registration locally and schedules retry when seed is offline.
  Future<void> attachOfflineRegistrationSession(String username) async {
    final hub = _hub;
    if (hub == null) return;
    _activeUsername = username;

    _publicEndpoint = await _resolveAdvertisedEndpoint();
    hub.ledger.setWalletOnline(
      username,
      endpoint: _publicEndpoint,
      blockHeight: PercChainTip.height(hub.ledger),
      tipHash: PercChainTip.hash(hub.ledger),
    );

    hub.ledger.refreshPendingInboundTransfers();
    if (!disableLiveNodesForTests) {
      _startReceivePolling();
    }
    if (hasPendingRegistrationRecovery) {
      scheduleDeepSync();
    }
    notifyListeners();
  }

  /// Tip-only sync — fast enough for splash/login (FlyClient).
  Future<void> quickSyncToNetworkHeight() async {
    await syncToNetworkHeight(quick: true);
  }

  /// Full ledger merge — runs after quick sync or on manual "Sync wallet".
  Future<void> deepSyncToNetworkHeight() async {
    await syncToNetworkHeight(quick: false);
  }

  /// Background catch-up after the shell is visible.
  void scheduleDeepSync() {
    final hub = _hub;
    if (hub == null || _deepSyncRunning) return;
    _deepSyncRunning = true;
    unawaited(() async {
      try {
        await _runDeepSyncBody(hub);
      } catch (_) {
        // Background sync must not surface to splash/login.
      } finally {
        _deepSyncRunning = false;
        notifyListeners();
      }
    }());
  }

  @visibleForTesting
  Future<void> runDeepSyncForTest() async {
    final hub = _hub;
    if (hub == null) return;
    await _runDeepSyncBody(hub);
    notifyListeners();
  }

  Future<void> _runDeepSyncBody(PercLedgerHub hub) async {
    if (!disableLiveNodesForTests) {
      await _syncWithRetries(hub, attempts: 2);
    }
    _applyTestSeedForPendingRegistration(hub);
    hub.ledger.refreshPendingInboundTransfers();
    final session = hub.ledger.sessionUsername;
    if (session != null) {
      hub.ledger.reconcileSessionStakingFromChain(session, applyCredits: true);
    }
    await hub.persistLocal();
    await _maybeNotifyPendingRegistrationRecovery(hub);
    if (hasPendingRegistrationRecovery && !isPendingRegistrationAligned(hub)) {
      _schedulePendingRegistrationDeepSyncRetry();
    }
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

  /// Adopts the canonical seed chain before a new registration is persisted.
  Future<PercRegistrationSeedAdoption> adoptSeedChainForRegistration({
    required String username,
    required String password,
    List<String>? seedMnemonic,
  }) async {
    final hub = _hub;
    if (hub == null) {
      return const PercRegistrationSeedAdoption(
        seedReachable: false,
        isAligned: false,
        seedHeight: 0,
        seedTipHash: '',
        seedChainId: PercChainConstants.evolutionaryChainId,
      );
    }

    _syncState = PercNetworkSyncState.syncing;
    notifyListeners();

    var seedReachable = false;
    PercLedger? seedLedger;
    var seedStatus = PercNetworkStatus(
      evolutionaryChainId: PercChainAlignment.effectiveChainId(hub.ledger),
      blockHeight: PercChainTip.height(hub.ledger),
      tipHash: PercChainTip.hash(hub.ledger),
      revision: hub.revision,
      networkGenesisRevision: hub.ledger.networkGenesisRevision,
    );

    if (disableLiveNodesForTests) {
      if (testSeedReachable && testSeedLedger != null) {
        seedLedger = PercLedger.fromJson(testSeedLedger!.toJson());
        seedStatus = PercNetworkStatus.fromLedger(
          seedLedger,
          revision: 1,
          endpoint: 'http://test-seed/perc',
        );
        _applySeedLedgerToHub(hub, seedLedger, seedStatus);
        seedReachable = true;
      } else {
        _seedConnected = false;
        _networkBlockHeight = _maxKnownHeight();
      }
    } else {
      final fetched = await _fetchAndApplyCanonicalSeed(hub);
      seedReachable = fetched.reachable;
      seedLedger = fetched.ledger;
      if (fetched.reachable) {
        seedStatus = fetched.status;
      }
    }

    _reapplyRegistrationAccount(
      hub,
      username: username,
      password: password,
      seedMnemonic: seedMnemonic,
    );

    final imported = _importedSeedTarget(hub);
    final target = imported ??
        (seedReachable
            ? SeedAlignmentTarget(
                chainId: seedStatus.evolutionaryChainId.isEmpty
                    ? PercChainConstants.evolutionaryChainId
                    : seedStatus.evolutionaryChainId,
                height: seedStatus.blockHeight,
                tipHash: seedStatus.tipHash,
              )
            : SeedAlignmentTarget.fromLedger(hub.ledger));

    // Alignment requires an imported ledger snapshot — status probes alone are not authoritative.
    final aligned = seedReachable &&
        imported != null &&
        PercChainAlignment.isAlignedWithSeed(
          local: hub.ledger,
          seedChainId: imported.chainId,
          seedHeight: imported.height,
          seedTipHash: imported.tipHash,
        );

    if (seedReachable && imported != null) {
      _networkBlockHeight = imported.height;
      _syncState = aligned
          ? PercNetworkSyncState.synced
          : PercChainAlignment.syncStateForSeed(
              local: hub.ledger,
              seedHeight: imported.height,
              seedTipHash: imported.tipHash,
            );
    } else if (disableLiveNodesForTests) {
      _syncState = PercNetworkSyncState.synced;
    } else {
      _syncState = PercNetworkSyncState.syncing;
    }
    notifyListeners();

    return PercRegistrationSeedAdoption(
      seedReachable: seedReachable,
      isAligned: aligned,
      seedHeight: target.height,
      seedTipHash: target.tipHash,
      seedChainId: target.chainId,
    );
  }

  void _reapplyRegistrationAccount(
    PercLedgerHub hub, {
    required String username,
    required String password,
    List<String>? seedMnemonic,
  }) {
    final u = PercAuth.normalizeUsername(username);
    if (!hub.ledger.accounts.containsKey(u)) {
      hub.ledger.register(u, password);
    }
    hub.ledger.login(u, password);
    if (seedMnemonic != null && seedMnemonic.isNotEmpty) {
      hub.ledger.attachSeedRecoveryEnvelope(
        username: u,
        mnemonic: seedMnemonic,
      );
    }
  }

  void _reapplyPendingRegistrationIfNeeded(PercLedgerHub hub) {
    final username = _pendingRegistrationUsername;
    final password = _pendingRegistrationPassword;
    if (username == null || password == null) return;
    _reapplyRegistrationAccount(
      hub,
      username: username,
      password: password,
      seedMnemonic: _pendingRegistrationMnemonic,
    );
  }

  /// Fetches the internet seed status + ledger and imports/resets local state.
  Future<({
    bool reachable,
    PercLedger? ledger,
    PercNetworkStatus status,
  })> _fetchAndApplyCanonicalSeed(PercLedgerHub hub) async {
    final fallbackStatus = PercNetworkStatus(
      evolutionaryChainId: PercChainAlignment.effectiveChainId(hub.ledger),
      blockHeight: PercChainTip.height(hub.ledger),
      tipHash: PercChainTip.hash(hub.ledger),
      revision: hub.revision,
      networkGenesisRevision: hub.ledger.networkGenesisRevision,
    );

    final base = await _rendezvous.baseUrl();
    if (base == null) {
      _seedConnected = false;
      return (reachable: false, ledger: null, status: fallbackStatus);
    }

    final config = await PercNetworkConfig.load();
    final seedUser = config.seedUsername.isNotEmpty
        ? config.seedUsername
        : PercChainConstants.seedUsername;
    final targetGenesis = config.networkGenesisRevision;

    var seedStatus = await _client.fetchStatus(base);
    if (seedStatus == null) {
      _seedConnected = false;
      return (reachable: false, ledger: null, status: fallbackStatus);
    }

    seedStatus = _flyClient.normalizeSeedStatus(
      seedStatus,
      seedUser: seedUser,
      baseEndpoint: base,
      targetGenesis: targetGenesis,
    );
    hub.ledger.updatePeerFromStatus(
      _statusWithImportedSeedTip(seedStatus, hub),
      online: true,
    );
    _seedConnected = true;
    _networkBlockHeight = _importedSeedTarget(hub)?.height ??
        _flyClient.networkHeightAfterProbe(
          local: hub.ledger,
          seedStatus: seedStatus,
        );

    var remote = await _client.fetchLedger(base);
    remote ??= await _rendezvous.fetchRelayedLedger(username: seedUser);
    if (remote == null) {
      return (reachable: true, ledger: null, status: seedStatus);
    }

    _applySeedLedgerToHub(hub, remote, seedStatus);
    return (reachable: true, ledger: remote, status: seedStatus);
  }

  void _applySeedLedgerToHub(
    PercLedgerHub hub,
    PercLedger remote,
    PercNetworkStatus seedStatus,
  ) {
    hub.ledger.updatePeerFromStatus(
      _statusWithImportedSeedTip(seedStatus, hub),
      online: true,
    );
    _seedConnected = true;

    final localHeight = PercChainTip.height(hub.ledger);
    final remoteHeight = PercChainTip.height(remote);
    final seedGenesis = remote.networkGenesisRevision;
    final targetGenesis = hub.ledger.networkGenesisRevision;
    final mustResetGenesis = seedGenesis > hub.ledger.networkGenesisRevision ||
        (seedGenesis >= targetGenesis &&
            localHeight > remoteHeight &&
            remoteHeight == 0);

    if (mustResetGenesis) {
      hub.resetFromSeedLedger(
        remote,
        expectedTipHash: PercChainTip.hash(remote),
      );
    } else {
      hub.ledger.mergeNetworkStateFromPeer(remote);
      if (remoteHeight > localHeight) {
        hub.importPeerLedger(
          remote,
          expectedTipHash: PercChainTip.hash(remote),
        );
      }
    }
    _reapplyPendingRegistrationIfNeeded(hub);
    _refreshSeedPeerFromLedger(hub, remote, seedStatus: seedStatus);
  }

  /// Manual sync — pull from seed, merge peers, re-publish wallet, gossip chain.
  Future<void> forceSyncWalletToSeed() async {
    final hub = _hub;
    if (hub == null) return;

    _syncState = PercNetworkSyncState.syncing;
    notifyListeners();

    if (!disableLiveNodesForTests) {
      await _connectToSeedNode(hub, deep: true);
    } else if (testSeedReachable && testSeedLedger != null) {
      final seed = PercLedger.fromJson(testSeedLedger!.toJson());
      final status = PercNetworkStatus.fromLedger(
        seed,
        revision: 1,
        endpoint: 'http://test-seed/perc',
      );
      _applySeedLedgerToHub(hub, seed, status);
    }
    hub.ledger.refreshPendingInboundTransfers();
    await deepSyncToNetworkHeight();
    _reapplyPendingRegistrationIfNeeded(hub);

    final session = hub.ledger.sessionUsername;
    if (session != null) {
      hub.ledger.reconcileSessionStakingFromChain(session, applyCredits: true);
    }
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
    await syncInboundState();
    scheduleInboundBurst();
    _reconcileSeedConnectivityAfterSync(hub);
    await gossipToPeers();
    notifyListeners();
  }

  /// Seed HTTP may fail transiently while ledger merge still advances — avoid stale offline.
  void _reconcileSeedConnectivityAfterSync(PercLedgerHub hub) {
    final localHeight = PercChainTip.height(hub.ledger);
    if (_syncState == PercNetworkSyncState.synced ||
        localHeight >= _networkBlockHeight) {
      _seedConnected = true;
    }
  }

  Future<void> syncToNetworkHeight({bool quick = false}) async {
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

    await _connectToSeedNode(hub, deep: !quick);

    final blockHeight = PercChainTip.height(hub.ledger);
    final tipHash = PercChainTip.hash(hub.ledger);
    hub.ledger.ensureNetworkNodes(
      blockHeight: blockHeight,
      tipHash: tipHash,
    );
    refreshSeedPeerFromLocalLedger();

    await _mergeRendezvousPeers(hub.ledger);

    final peerStatuses = quick
        ? await _collectSeedPeerStatuses(hub.ledger)
        : await _collectPeerStatuses(hub.ledger);
    refreshSeedPeerFromLocalLedger();
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

    if (!quick && targetHeight > PercChainTip.height(hub.ledger)) {
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

    if (!quick) {
      await _mergeInboundFromRendezvousPeers(hub);
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

    _reconcileSeedConnectivityAfterSync(hub);
    notifyListeners();
  }

  Future<void> gossipToPeers({bool deepSyncAfter = true}) async {
    final generation = _networkGeneration;
    final hub = _hub;
    if (hub == null || disableLiveNodesForTests) return;
    if (!_isNetworkGenerationCurrent(generation)) return;
    final ledger = hub.ledger;
    final localEndpoint = nodeEndpoint;
    final session = ledger.sessionUsername;

    if (session != null && _isNetworkGenerationCurrent(generation)) {
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
        .where((n) => n.online && (n.endpoint ?? '').isNotEmpty)
        .map((n) => n.endpoint!)
        .where((e) => e != localEndpoint)
        .toSet();
    final internetTargets =
        gossipTargets.where(PercPublicEndpoint.isInternetEndpoint).toList();
    final targets =
        internetTargets.isNotEmpty ? internetTargets : gossipTargets.toList();

    for (final endpoint in targets.take(8)) {
      if (!_isNetworkGenerationCurrent(generation)) return;
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
    if (deepSyncAfter && _isNetworkGenerationCurrent(generation)) {
      await syncToNetworkHeight();
    }
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

  /// Fetches live sender ledgers for pending cross-device inbound transfers.
  Future<void> prefetchSenderPeersForPending(String receiverUsername) async {
    _senderPeerCache.clear();
    final hub = _hub;
    if (hub == null) return;

    final pending = hub.ledger.pendingInboundFor(receiverUsername);
    final remoteSenders = pending
        .where((p) {
          final acc = hub.ledger.account(p.fromUsername);
          return acc == null || !acc.passwordSet;
        })
        .map((p) => p.fromUsername)
        .toSet();

    for (final from in remoteSenders) {
      final peer = await _fetchSenderPeerLedger(from);
      if (peer != null) {
        _senderPeerCache[from] = peer;
      }
    }
  }

  Future<PercLedger?> _fetchSenderPeerLedger(String username) async {
    if (_senderPeerCache.containsKey(username)) {
      return _senderPeerCache[username];
    }
    final hub = _hub;
    if (hub == null) return null;

    final node = hub.ledger.networkNodes[username];
    final endpoint = node?.endpoint;
    if (endpoint != null &&
        endpoint.isNotEmpty &&
        PercPublicEndpoint.isInternetEndpoint(endpoint)) {
      final remote = await _client.fetchLedger(endpoint);
      if (remote != null) return remote;
    }

    final relayed = await _rendezvous.fetchRelayedLedger(username: username);
    if (relayed != null) return relayed;

    final acc = hub.ledger.account(username);
    if (acc != null && acc.address.isNotEmpty) {
      return _rendezvous.fetchRelayedLedger(address: acc.address);
    }
    return null;
  }

  /// Publishes encrypted seed recovery envelopes for the signed-in wallet.
  Future<void> publishSeedRecoveryEnvelopes() async {
    if (disableLiveNodesForTests) return;
    final hub = _hub;
    final session = hub?.ledger.sessionUsername;
    if (hub == null || session == null) return;
    final acc = hub.ledger.account(session);
    final fingerprint = acc?.seedFingerprint;
    final envelope = acc?.seedRecoveryEnvelope;
    if (fingerprint == null ||
        fingerprint.isEmpty ||
        envelope == null ||
        envelope.isEmpty) {
      return;
    }
    await _rendezvous.publishSeedRecoveryEnvelope(
      fingerprint: fingerprint,
      envelopeB64: envelope,
    );
  }

  /// Pushes settlement witnesses to sender rendezvous slots after receiver scenario.
  Future<void> propagateSettlementWitnesses() async {
    final hub = _hub;
    if (hub == null || hub.ledger.settlementWitnesses.isEmpty) return;

    final senders = <String>{};
    for (final witness in hub.ledger.settlementWitnesses) {
      final from = hub.ledger.lookupTransferSender(witness.transferId);
      if (from != null) senders.add(from);
    }

    if (disableLiveNodesForTests) {
      for (final sender in senders) {
        final target = settlementPeerTargets[sender];
        if (target != null) {
          target.ingestSettlementWitnessFromReceiver(hub.ledger);
        }
      }
      return;
    }

    for (final sender in senders) {
      await pushLedgerToRecipient(username: sender, ledger: hub.ledger);
    }
  }

  /// Pulls network state and settles inbound PERC for the signed-in wallet.
  /// Merges relayed peer ledgers and settles inbound PERC without replacing
  /// a local chain tip that is already ahead of the network.
  Future<void> syncInboundState() async {
    final hub = _hub;
    if (hub == null) return;
    await _mergeInboundFromRendezvousPeers(hub);
    hub.ledger.refreshPendingInboundTransfers();
    notifyListeners();
  }

  /// Pushes the sender ledger toward the recipient rendezvous slot and endpoint.
  Future<void> pushLedgerToRecipient({
    required PercLedger ledger,
    String? username,
    String? address,
  }) async {
    final session = ledger.sessionUsername;
    final normalizedUser = username?.trim();
    if (session != null) {
      await _rendezvous.relayLedger(
        username: session,
        ledger: ledger,
        notifyRecipientUsername: normalizedUser,
      );
    }
    if (disableLiveNodesForTests) return;
    if (normalizedUser != null && normalizedUser.isNotEmpty) {
      final node = ledger.networkNodes[normalizedUser];
      final endpoint = node?.endpoint;
      if (endpoint != null && endpoint.isNotEmpty) {
        await _client.pushLedger(endpoint: endpoint, ledger: ledger);
      }
    }
  }

  /// Lightweight seed poll — tip probe plus rendezvous inbound merge.
  Future<void> pollForInboundTransfers() async {
    final hub = _hub;
    if (hub == null || _activeUsername == null) return;

    final heightBefore = PercChainTip.height(hub.ledger);
    final pendingBefore = hub.ledger.pendingInboundFor(_activeUsername!).length;
    final balanceBefore = hub.ledger.sessionBalance;

    await _heartbeatSessionToSeed();
    await quickSyncToNetworkHeight();
    await syncInboundState();
    hub.ledger.refreshPendingInboundTransfers();

    final changed = PercChainTip.height(hub.ledger) != heightBefore ||
        hub.ledger.pendingInboundFor(_activeUsername!).length != pendingBefore ||
        hub.ledger.sessionBalance != balanceBefore;

    if (changed) {
      await hub.persistLocal();
    }
    await _maybeScheduleBurstAfterPoll(hub);
    notifyListeners();
  }

  /// Foreground burst inbound sync — tab focus, resume, or relay PUT hints.
  void scheduleInboundBurst({
    List<String>? senderUsernames,
    bool immediate = true,
  }) {
    final hub = _hub;
    if (hub == null || _activeUsername == null || _appInBackground) return;

    final now = DateTime.now();
    if (_lastBurstStarted != null &&
        now.difference(_lastBurstStarted!) <
            AppPerformance.inboundBurstCooldown &&
        _burstAttemptsRemaining <= 0) {
      return;
    }

    if (senderUsernames != null) {
      for (final sender in senderUsernames) {
        final normalized = sender.trim();
        if (normalized.isNotEmpty) {
          _burstSenderTargets.add(normalized);
        }
      }
    }

    _burstAttemptsRemaining = AppPerformance.inboundBurstMaxAttempts;
    _lastBurstStarted = now;
    _burstPollTimer?.cancel();

    if (immediate) {
      unawaited(_runBurstInboundCycle());
    } else {
      _scheduleNextBurstTick();
    }
  }

  @visibleForTesting
  Future<void> runBurstInboundCycleForTest() async {
    if (_burstAttemptsRemaining <= 0) {
      _burstAttemptsRemaining = 1;
    }
    await _runBurstInboundCycle();
  }

  /// Runs one burst cycle — used by [PercWalletProvider.refreshInboundNow].
  Future<void> runFirstBurstCycle() async {
    if (_burstAttemptsRemaining <= 0) {
      scheduleInboundBurst(immediate: false);
    }
    await _runBurstInboundCycle();
  }

  Future<void> _runBurstInboundCycle() async {
    final hub = _hub;
    if (hub == null ||
        _activeUsername == null ||
        _burstAttemptsRemaining <= 0 ||
        _appInBackground) {
      _stopBurstPolling();
      return;
    }

    _burstAttemptsRemaining--;
    final changed = await _syncInboundBurst(hub);
    if (changed) {
      await hub.persistLocal();
      _burstAttemptsRemaining = 0;
      _stopBurstPolling();
      notifyListeners();
      return;
    }

    if (_burstAttemptsRemaining > 0) {
      _scheduleNextBurstTick();
    } else {
      _stopBurstPolling();
    }
    notifyListeners();
  }

  void _scheduleNextBurstTick() {
    _burstPollTimer?.cancel();
    if (_burstAttemptsRemaining <= 0) return;
    _burstPollTimer = Timer(AppPerformance.inboundBurstPollInterval, () {
      unawaited(_runBurstInboundCycle());
    });
  }

  void _stopBurstPolling() {
    _burstPollTimer?.cancel();
    _burstPollTimer = null;
    _burstAttemptsRemaining = 0;
    _burstSenderTargets.clear();
    _lastBurstStarted = null;
  }

  Future<bool> _syncInboundBurst(PercLedgerHub hub) async {
    final session = _activeUsername!;
    final balanceBefore = hub.ledger.sessionBalance;
    final pendingBefore = hub.ledger.pendingInboundFor(session).length;

    await _fetchTargetedInboundRelays(hub);
    hub.ledger.refreshPendingInboundTransfers();

    return hub.ledger.sessionBalance != balanceBefore ||
        hub.ledger.pendingInboundFor(session).length != pendingBefore;
  }

  Future<void> _fetchTargetedInboundRelays(PercLedgerHub hub) async {
    final session = _activeUsername!;
    final targets = <String>{..._burstSenderTargets};

    final hints = await _rendezvous.fetchInboundRelayHints(
      recipientUsername: session,
    );
    for (final hint in hints) {
      targets.add(hint.senderUsername);
    }

    for (final pending in hub.ledger.pendingInboundFor(session)) {
      final acc = hub.ledger.account(pending.fromUsername);
      if (acc == null || !acc.passwordSet) {
        targets.add(pending.fromUsername);
      }
    }

    for (final sender in targets) {
      await _applyRelayFromSenderSlot(hub, sender);
    }
  }

  Future<void> _applyRelayFromSenderSlot(
    PercLedgerHub hub,
    String senderUsername,
  ) async {
    final relayed =
        await _rendezvous.fetchRelayedLedger(username: senderUsername);
    if (relayed == null) return;
    hub.ledger.applyInboundRelayFromSender(relayed);
    hub.ledger.reconcileSettledTransfersFromPeer(relayed);
    _burstSenderTargets.remove(senderUsername);
  }

  Future<void> _maybeScheduleBurstAfterPoll(PercLedgerHub hub) async {
    if (_appInBackground || _activeUsername == null) return;

    final session = _activeUsername!;
    final hints = await _rendezvous.fetchInboundRelayHints(
      recipientUsername: session,
    );
    if (hints.isNotEmpty) {
      scheduleInboundBurst(
        senderUsernames: hints.map((h) => h.senderUsername).toList(),
        immediate: true,
      );
      return;
    }

    final remotePendingSenders = hub.ledger
        .pendingInboundFor(session)
        .where((pending) {
          final acc = hub.ledger.account(pending.fromUsername);
          return acc == null || !acc.passwordSet;
        })
        .map((pending) => pending.fromUsername)
        .toSet();
    if (remotePendingSenders.isNotEmpty) {
      scheduleInboundBurst(senderUsernames: remotePendingSenders.toList());
    }
  }

  /// Slow network polling while the app is minimized or on another desktop.
  void setAppInBackground(bool inBackground) {
    if (_appInBackground == inBackground) return;
    _appInBackground = inBackground;
    if (inBackground) {
      _stopBurstPolling();
    } else {
      scheduleInboundBurst();
    }
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
    unawaited(pollForInboundTransfers());
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
    _stopBurstPolling();
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

  bool _canPublishSessionToSeed(PercLedgerHub hub) {
    if (!hasPendingRegistrationRecovery) return true;
    return isPendingRegistrationAligned(hub);
  }

  Future<void> _registerSessionOnSeed(
    PercLedgerHub hub,
    PercNetworkStatus status,
  ) async {
    if (status.endpoint == null || status.sessionUsername == null) return;
    if (!_canPublishSessionToSeed(hub)) return;
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

  bool _isResolvableManualRecipient(PercAccount? account, PercLedger ledger) {
    if (account == null) return false;
    return !ledger.isManualReceiveBlocked(account.username);
  }

  /// Resolves a PERC address to an account — local first, then network rendezvous.
  /// evolve_treasury is omitted after launch (no manual receive address).
  Future<PercAccount?> resolveAccountByAddress(String address) async {
    final hub = _hub;
    if (hub == null) return null;
    final normalized = PercAuth.normalizeAddress(address);
    if (PercAuth.validateAddress(normalized) != null) return null;

    var local = hub.ledger.accountForAddress(normalized);
    if (_isResolvableManualRecipient(local, hub.ledger)) return local!;

    await syncToNetworkHeight();
    final seedLedger = await _fetchSeedLedgerForDiscovery();
    if (seedLedger != null) {
      hub.ledger.mergeNetworkStateFromPeer(seedLedger);
    }
    local = hub.ledger.accountForAddress(normalized);
    if (_isResolvableManualRecipient(local, hub.ledger)) return local!;

    local = await _discoverAccountOnNetwork(normalized);
    if (_isResolvableManualRecipient(local, hub.ledger)) return local!;

    return null;
  }

  Future<void> _mergeInboundFromRendezvousPeers(PercLedgerHub hub) async {
    if (disableLiveNodesForTests) return;
    final seen = <String>{};

    Future<void> mergeRelay({String? username, String? address}) async {
      final u = username?.trim();
      final a = address?.trim();
      if ((u == null || u.isEmpty) && (a == null || a.isEmpty)) return;
      final key = '${u ?? ''}|${a ?? ''}';
      if (seen.contains(key)) return;
      seen.add(key);
      final relayed = await _rendezvous.fetchRelayedLedger(
        username: u,
        address: a,
      );
      if (relayed != null) {
        hub.ledger.applyInboundRelayFromSender(relayed);
        hub.ledger.reconcileSettledTransfersFromPeer(relayed);
      }
    }

    final session = hub.ledger.sessionUsername;
    if (session != null) {
      final hints = await _rendezvous.fetchInboundRelayHints(
        recipientUsername: session,
      );
      for (final hint in hints) {
        await mergeRelay(username: hint.senderUsername);
      }
    }

    final peers = await _rendezvous.fetchPeers();
    for (final status in peers) {
      await mergeRelay(
        username: status.sessionUsername,
        address: status.walletAddress,
      );
    }

    // Sender may be offline from the live peer list but still have a relay slot.
    for (final entry in hub.ledger.networkNodes.entries.toList()) {
      final nodeUser = entry.key.trim();
      if (nodeUser.isEmpty ||
          nodeUser == PercChainConstants.seedUsername ||
          nodeUser == PercChainConstants.treasuryUsername) {
        continue;
      }
      await mergeRelay(username: nodeUser);
    }

    final sessionAddr = hub.ledger.sessionAccount?.address;
    if (sessionAddr != null && sessionAddr.isNotEmpty) {
      await mergeRelay(address: sessionAddr);
    }
    if (session != null) {
      hub.ledger.refreshPendingInboundTransfers();
    }
  }

  Future<PercLedger?> _fetchSeedLedgerForDiscovery() async {
    if (disableLiveNodesForTests) return null;
    final base = await _rendezvous.baseUrl();
    if (base == null) return null;
    return _client.fetchLedger(base);
  }

  Future<PercAccount?> _discoverAccountOnNetwork(String normalized) async {
    final hub = _hub;
    if (hub == null || disableLiveNodesForTests) return null;

    PercAccount? _localHit() => hub.ledger.accountForAddress(normalized);

    void _mergeRemote(PercLedger remote) =>
        hub.ledger.mergeNetworkStateFromPeer(remote);

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
  Future<void> _connectToSeedNode(PercLedgerHub hub, {required bool deep}) async {
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
    final targetGenesis = config.networkGenesisRevision;

    var seedStatus = await _client.fetchStatus(base);
    if (seedStatus == null) {
      _seedConnected = false;
      return;
    }

    seedStatus = _flyClient.normalizeSeedStatus(
      seedStatus,
      seedUser: seedUser,
      baseEndpoint: base,
      targetGenesis: targetGenesis,
    );
    hub.ledger.updatePeerFromStatus(
      _statusWithImportedSeedTip(seedStatus, hub),
      online: true,
    );
    _seedConnected = true;
    _networkBlockHeight = _importedSeedTarget(hub)?.height ??
        _flyClient.networkHeightAfterProbe(
          local: hub.ledger,
          seedStatus: seedStatus,
        );

    if (!deep) {
      _syncState = _flyClient.syncStateAfterQuickProbe(
        local: hub.ledger,
        networkHeight: _networkBlockHeight,
      );
      return;
    }

    if (!_flyClient.needsFullLedger(
      local: hub.ledger,
      seedStatus: seedStatus,
      targetGenesis: targetGenesis,
    )) {
      return;
    }

    var remote = await _client.fetchLedger(base);
    remote ??= await _rendezvous.fetchRelayedLedger(username: seedUser);
    if (remote == null) return;

    _applySeedLedgerToHub(hub, remote, seedStatus);
  }

  Future<List<PercNetworkStatus>> _collectSeedPeerStatuses(
    PercLedger ledger,
  ) async {
    final seedEndpoint = ledger.networkNodes[PercChainConstants.seedUsername]
        ?.endpoint;
    if (seedEndpoint == null || seedEndpoint.isEmpty) return const [];
    final status = await _client.fetchStatus(seedEndpoint);
    if (status == null) return const [];
    _seedConnected = true;
    final hub = _hub;
    final corrected = hub != null
        ? _statusWithImportedSeedTip(status, hub)
        : status;
    ledger.updatePeerFromStatus(corrected, online: true);
    if (hub != null) refreshSeedPeerFromLocalLedger();
    return [corrected];
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