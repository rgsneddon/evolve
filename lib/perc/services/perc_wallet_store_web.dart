import 'dart:convert';
import 'dart:html' as html;

import 'perc_ledger.dart';
import 'perc_wallet_store.dart';

PercWalletStore createPercWalletStore() => PercWalletStoreWeb();

/// Web persistence — shared localStorage so every tab uses the same ledger.
class PercWalletStoreWeb implements PercWalletStore {
  static const storageKey =
      'perc_evolve-chronoflux-principia-chain-1_ledger';
  static const legacyStorageKey = 'perc_perccent_ledger_v1';

  @override
  Future<PercLedger?> load() async {
    var raw = html.window.localStorage[storageKey];
    if (raw == null || raw.trim().isEmpty) {
      raw = html.window.localStorage[legacyStorageKey];
    }
    if (raw == null || raw.trim().isEmpty) return null;
    return PercLedger.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(PercLedger ledger) async {
    final encoded = jsonEncode(ledger.toJson());
    html.window.localStorage[storageKey] = encoded;
    html.window.localStorage.remove(legacyStorageKey);
  }
}