import 'perc_flutter_test_detect_stub.dart'
    if (dart.library.io) 'perc_flutter_test_detect_io.dart' as ftd;
import 'perc_node_server.dart';
import 'perc_node_server_stub.dart' as node_stub;
import 'perc_node_server_stub.dart'
    if (dart.library.io) 'perc_node_server_io.dart' as node_impl;

/// Never bind fixed port 9477 during `flutter test` — avoids parallel-suite flakes.
bool get _useLiveNodeServer =>
    !const bool.fromEnvironment('FLUTTER_TEST') && !ftd.isFlutterTest;

PercNodeServer createPercNodeServer() => _useLiveNodeServer
    ? node_impl.createPercNodeServer()
    : node_stub.createPercNodeServerStub();