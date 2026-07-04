import 'perc_node_server.dart';
import 'perc_node_server_stub.dart' as node_stub;
import 'perc_node_server_stub.dart'
    if (dart.library.io) 'perc_node_server_io.dart' as node_impl;

bool get _useLiveNodeServer => !const bool.fromEnvironment('FLUTTER_TEST');

PercNodeServer createPercNodeServer() => _useLiveNodeServer
    ? node_impl.createPercNodeServer()
    : node_stub.createPercNodeServerStub();