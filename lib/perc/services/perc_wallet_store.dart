import 'perc_ledger.dart';

abstract class PercWalletStore {
  Future<PercLedger?> load();
  Future<void> save(PercLedger ledger);
}