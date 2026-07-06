import 'perc_ledger.dart';
import 'perc_wallet_store.dart';

/// In-memory store for tests.
class PercWalletStoreMemory implements PercWalletStore {
  PercLedger? _ledger;

  @override
  Future<PercLedger?> load() async => _ledger;

  @override
  Future<void> save(PercLedger ledger) async {
    _ledger = ledger;
  }
}