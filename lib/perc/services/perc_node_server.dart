import 'perc_ledger_hub.dart';

/// Lightweight HTTP surface served by an online Perccent wallet.
abstract class PercNodeServer {
  bool get supportsLiveServing;
  Future<void> start(PercLedgerHub hub);
  Future<void> stop();
  String? get endpoint;
  bool get isRunning;
}