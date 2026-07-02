import 'dart:convert';
import 'dart:html' as html;

import 'perc_ledger.dart';
import 'perc_wallet_store.dart';

PercWalletStore createPercWalletStore() => PercWalletStoreWeb();

/// Web persistence — shared localStorage so every tab uses the same ledger.
class PercWalletStoreWeb implements PercWalletStore {
  static const storageKey = 'perc_perccent_ledger_v1';

  @override
  Future<PercLedger?> load() async {
    final raw = html.window.localStorage[storageKey];
    if (raw == null || raw.trim().isEmpty) return null;
    return PercLedger.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(PercLedger ledger) async {
    html.window.localStorage[storageKey] = jsonEncode(ledger.toJson());
  }
}