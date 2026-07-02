import 'dart:convert';

import 'perc_ledger.dart';
import 'perc_wallet_store.dart';
import 'perc_wallet_store_memory.dart';

/// Web / fallback — uses in-memory persistence for the session.
class PercWalletStoreStub implements PercWalletStore {
  final _memory = PercWalletStoreMemory();
  String? _cachedJson;

  @override
  Future<PercLedger?> load() async {
    if (_cachedJson != null) {
      return PercLedger.fromJson(
        jsonDecode(_cachedJson!) as Map<String, dynamic>,
      );
    }
    return _memory.load();
  }

  @override
  Future<void> save(PercLedger ledger) async {
    _cachedJson = jsonEncode(ledger.toJson());
    await _memory.save(ledger);
  }
}