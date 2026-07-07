import 'dart:async';

import 'package:flutter/foundation.dart';

import '../perc_app_version.dart';
import 'perc_chain_evolution.dart';
import 'perc_chain_tip.dart';
import 'perc_ledger.dart';
import 'perc_ledger_hub_sync_stub.dart'
    if (dart.library.html) 'perc_ledger_hub_sync_web.dart' as hub_sync;
import 'perc_network_coordinator.dart';
import 'perc_wallet_store.dart';

/// Shared Perccent ledger — all wallets read/write the same chain concurrently.
class PercLedgerHub extends ChangeNotifier {
  PercLedgerHub._();

  static final PercLedgerHub instance = PercLedgerHub._();

  PercLedger _ledger = PercLedger.empty();
  PercWalletStore? _store;
  bool _ready = false;
  int _revision = 0;
  void Function()? _cancelSync;
  final PercChainEvolution _evolution = const PercChainEvolution();
  final PercNetworkCoordinator network = PercNetworkCoordinator.instance;

  PercLedger get ledger => _ledger;
  int get revision => _revision;
  bool get isReady => _ready;

  @visibleForTesting
  static void resetForTest() {
    instance._cancelSync?.call();
    instance._cancelSync = null;
    instance._ledger = PercLedger.empty();
    instance._store = null;
    instance._ready = false;
    instance._revision = 0;
    PercNetworkCoordinator.resetForTest();
    PercNetworkCoordinator.disableLiveNodesForTests = true;
  }

  Future<void> initialize(PercWalletStore store) async {
    if (_ready && identical(_store, store)) return;
    _cancelSync?.call();
    _store = store;
    final loaded = await store.load();
    _ledger = loaded ?? PercLedger.empty();
    final evolved = _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _ready = true;
    _revision++;
    notifyListeners();
    if (evolved) await store.save(_ledger);
    _cancelSync = hub_sync.bindCrossTabSync(
      onRemoteRevision: () => unawaited(reloadFromStore()),
    );
    // Load local ledger first; sync to the seed node in the background so the
    // shell can appear without waiting on network I/O (especially on Windows).
    final networkBind = network.bind(this);
    if (PercNetworkCoordinator.disableLiveNodesForTests) {
      await networkBind;
    } else {
      unawaited(networkBind);
    }
  }

  Future<void> reloadFromStore() async {
    final store = _store;
    if (store == null) return;
    final loaded = await store.load();
    if (loaded == null) return;
    _evolution.evolveLedger(loaded, appVersion: PercAppVersion.current);
    _ledger = loaded;
    _revision++;
    notifyListeners();
    await network.quickSyncToNetworkHeight();
    network.scheduleDeepSync();
  }

  Future<void> onWalletSessionStarted(String username) async {
    await network.onSessionStarted(username);
  }

  Future<void> onWalletSessionEnded([String? username]) async {
    await network.onSessionEnded(username);
  }

  void resetFromSeedLedger(PercLedger remote, {String? expectedTipHash}) {
    final session = _ledger.sessionUsername;
    _ledger.resetFromSeedLedger(remote, expectedTipHash: expectedTipHash);
    if (session != null && _ledger.accounts.containsKey(session)) {
      _ledger.sessionUsername = session;
    }
    _revision++;
    notifyListeners();
  }

  void importPeerLedger(
    PercLedger remote, {
    String? expectedTipHash,
    bool force = false,
  }) {
    final session = _ledger.sessionUsername;
    _ledger.importPeerLedger(
      remote,
      expectedTipHash: expectedTipHash,
      force: force,
    );
    if (session != null && _ledger.accounts.containsKey(session)) {
      _ledger.sessionUsername = session;
      _ledger.refreshPendingInboundTransfers();
    }
    _revision++;
    notifyListeners();
  }

  void requireSyncedForMutation() => network.requireSyncedForMutation();

  /// Persist ledger to local storage without network sync (safe during app boot).
  Future<void> restoreFromBackup(PercLedger snapshot, {String? sessionUsername}) async {
    final session = sessionUsername ?? _ledger.sessionUsername;
    _ledger = PercLedger.fromJson(snapshot.toJson());
    if (session != null && _ledger.accounts.containsKey(session)) {
      _ledger.sessionUsername = session;
      _ledger.refreshPendingInboundTransfers();
    }
    _revision++;
    notifyListeners();
    await persistLocal();
  }

  Future<void> persistLocal() async {
    _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _ledger.refreshSeedRecoveryEnvelopes();
    _revision++;
    notifyListeners();
    await _store?.save(_ledger);
    hub_sync.broadcastRevision();
    await network.publishSeedRecoveryEnvelopes();
  }

  Future<void> commit() async {
    await commitWithoutSessionPromotion(promoteSessionNode: true);
  }

  /// Persists ledger after a manual seed sync without requiring network-sync gate.
  /// Persists a send, gossips to peers, then merges inbound state without
  /// replacing a taller local tip.
  Future<void> commitAfterSend({
    String? relayRecipientUsername,
    String? relayRecipientAddress,
  }) async {
    _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _ledger.refreshSeedRecoveryEnvelopes();
    _ledger.ensureNetworkNodes(
      blockHeight: PercChainTip.height(_ledger),
      tipHash: PercChainTip.hash(_ledger),
    );
    if (_ledger.sessionUsername != null) {
      _ledger.setWalletOnline(
        _ledger.sessionUsername!,
        endpoint: network.nodeEndpoint,
        blockHeight: PercChainTip.height(_ledger),
        tipHash: PercChainTip.hash(_ledger),
      );
    }
    _revision++;
    notifyListeners();
    await _store?.save(_ledger);
    hub_sync.broadcastRevision();
    await network.gossipToPeers();
    await network.pushLedgerToRecipient(
      username: relayRecipientUsername,
      address: relayRecipientAddress,
      ledger: _ledger,
    );
    await network.syncInboundState();
    await network.publishSeedRecoveryEnvelopes();
    notifyListeners();
  }

  /// Persists after scenario, gossips witnesses, and notifies senders to reconcile.
  Future<void> commitAfterScenario() async {
    _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _ledger.refreshSeedRecoveryEnvelopes();
    _ledger.ensureNetworkNodes(
      blockHeight: PercChainTip.height(_ledger),
      tipHash: PercChainTip.hash(_ledger),
    );
    if (_ledger.sessionUsername != null) {
      _ledger.setWalletOnline(
        _ledger.sessionUsername!,
        endpoint: network.nodeEndpoint,
        blockHeight: PercChainTip.height(_ledger),
        tipHash: PercChainTip.hash(_ledger),
      );
    }
    _revision++;
    notifyListeners();
    await _store?.save(_ledger);
    hub_sync.broadcastRevision();
    await network.gossipToPeers();
    await network.propagateSettlementWitnesses();
    await network.publishSeedRecoveryEnvelopes();
    notifyListeners();
  }

  Future<void> commitAfterForceSync() async {
    _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _ledger.refreshSeedRecoveryEnvelopes();
    _ledger.ensureNetworkNodes(
      blockHeight: PercChainTip.height(_ledger),
      tipHash: PercChainTip.hash(_ledger),
    );
    if (_ledger.sessionUsername != null) {
      _ledger.setWalletOnline(
        _ledger.sessionUsername!,
        endpoint: network.nodeEndpoint,
        blockHeight: PercChainTip.height(_ledger),
        tipHash: PercChainTip.hash(_ledger),
      );
    }
    _revision++;
    notifyListeners();
    await _store?.save(_ledger);
    hub_sync.broadcastRevision();
    await network.gossipToPeers();
    await network.publishSeedRecoveryEnvelopes();
  }

  Future<void> commitWithoutSessionPromotion({
    bool promoteSessionNode = false,
  }) async {
    await network.syncToNetworkHeight();
    network.requireSyncedForMutation();
    _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _ledger.ensureNetworkNodes(
      blockHeight: PercChainTip.height(_ledger),
      tipHash: PercChainTip.hash(_ledger),
    );
    if (promoteSessionNode && _ledger.sessionUsername != null) {
      _ledger.setWalletOnline(
        _ledger.sessionUsername!,
        endpoint: network.nodeEndpoint,
        blockHeight: PercChainTip.height(_ledger),
        tipHash: PercChainTip.hash(_ledger),
      );
    }
    _revision++;
    notifyListeners();
    await _store?.save(_ledger);
    hub_sync.broadcastRevision();
    await network.gossipToPeers();
  }
}