import 'dart:async';

import 'package:flutter/foundation.dart';

import '../perc_app_version.dart';
import 'perc_chain_evolution.dart';
import 'perc_ledger.dart';
import 'perc_ledger_hub_sync_stub.dart'
    if (dart.library.html) 'perc_ledger_hub_sync_web.dart' as hub_sync;
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
  }

  Future<void> initialize(PercWalletStore store) async {
    if (_ready && identical(_store, store)) return;
    _cancelSync?.call();
    _store = store;
    final loaded = await store.load();
    _ledger = loaded ?? PercLedger.empty();
    _ledger.ensureTreasuryAccount();
    _ledger.connectAllWalletsConcurrently();
    final evolved = _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _ready = true;
    _revision++;
    notifyListeners();
    if (evolved) await store.save(_ledger);
    _cancelSync = hub_sync.bindCrossTabSync(
      onRemoteRevision: () => unawaited(reloadFromStore()),
    );
  }

  Future<void> reloadFromStore() async {
    final store = _store;
    if (store == null) return;
    final loaded = await store.load();
    if (loaded == null) return;
    loaded.connectAllWalletsConcurrently();
    _evolution.evolveLedger(loaded, appVersion: PercAppVersion.current);
    _ledger = loaded;
    _revision++;
    notifyListeners();
  }

  Future<void> commit() async {
    _ledger.connectAllWalletsConcurrently();
    _evolution.evolveLedger(_ledger, appVersion: PercAppVersion.current);
    _revision++;
    notifyListeners();
    await _store?.save(_ledger);
    hub_sync.broadcastRevision();
  }
}