import 'dart:convert';
import 'dart:io';

import '../perc_chain_constants.dart';
import 'perc_ledger.dart';
import 'perc_ledger_hub.dart';
import 'perc_network_protocol.dart';
import 'perc_node_server.dart';
import 'perc_public_endpoint.dart';

PercNodeServer createPercNodeServer() => _PercNodeServerIo();

class _PercNodeServerIo implements PercNodeServer {
  @override
  bool get supportsLiveServing => true;

  HttpServer? _server;
  PercLedgerHub? _hub;
  String? _endpoint;
  final PercPublicEndpoint _publicEndpoint = const PercPublicEndpoint();

  @override
  String? get endpoint => _endpoint;

  @override
  bool get isRunning => _server != null;

  @override
  Future<void> start(PercLedgerHub hub) async {
    _hub = hub;
    if (_server != null) return;

    final port = PercChainConstants.defaultNodePort;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _endpoint = await _publicEndpoint.resolveInternetEndpoint(port: port) ??
        'http://127.0.0.1:$port';
    _server!.listen(_handleRequest);
  }

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _endpoint = null;
    _hub = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _applyCors(request);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final hub = _hub;
    if (hub == null) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    if (request.method == 'GET' && path == '/perc/status') {
      await _writeJson(
        request,
        PercNetworkStatus.fromLedger(
          hub.ledger,
          revision: hub.revision,
          endpoint: _endpoint,
        ).toJson(),
      );
      return;
    }

    if (path == '/perc/ledger') {
      if (request.method == 'GET') {
        await _writeJson(request, hub.ledger.toJson());
        return;
      }
      if (request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final remote = PercLedger.fromJson(json);
          hub.importPeerLedger(remote);
          await _writeJson(request, {'ok': true});
        } catch (_) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
        }
        return;
      }
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  void _applyCors(HttpRequest request) {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, OPTIONS',
    );
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );
  }

  Future<void> _writeJson(HttpRequest request, Object payload) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}