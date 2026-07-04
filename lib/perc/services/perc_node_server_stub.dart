import 'perc_ledger_hub.dart';
import 'perc_node_server.dart';

PercNodeServer createPercNodeServer() => _PercNodeServerStub();

PercNodeServer createPercNodeServerStub() => createPercNodeServer();

class _PercNodeServerStub implements PercNodeServer {
  @override
  bool get supportsLiveServing => false;

  @override
  String? get endpoint => null;

  @override
  bool get isRunning => false;

  @override
  Future<void> start(PercLedgerHub hub) async {}

  @override
  Future<void> stop() async {}
}