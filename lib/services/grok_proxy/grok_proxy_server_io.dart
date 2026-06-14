import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/grok_session.dart';
import 'grok_proxy_config.dart';
import 'grok_proxy_handler.dart';
import 'grok_proxy_store.dart';

/// Starts and manages the embedded Grok proxy on IO platforms.
class GrokProxyLauncher {
  GrokProxyLauncher._();

  static final GrokProxyLauncher instance = GrokProxyLauncher._();

  static const defaultPort = 8787;

  HttpServer? _server;
  GrokProxyStore? _store;
  int _port = defaultPort;

  bool get supportsEmbeddedProxy => true;
  bool get isRunning => _server != null;
  bool get isEmbedded => _store != null;
  int get port => _port;

  GrokSession get embeddedSession {
    if (_store == null) return const GrokSession();
    return GrokSession.fromJson(_store!.statusJson());
  }

  /// Complete OAuth on the in-process store (avoids localhost HTTP round-trips).
  Future<GrokSession> completeOAuthInProcess(String code, String? state) async {
    final store = _store;
    if (store == null) {
      throw StateError('Embedded Grok proxy is not running');
    }
    await store.completeOAuth(code, state);
    return GrokSession.fromJson(store.statusJson());
  }

  /// Bind localhost proxy, or reuse a healthy listener on [port].
  Future<void> ensureRunning({int port = defaultPort}) async {
    _port = port;

    if (_server != null && _store != null) {
      if (await _healthOk(port)) return;
      await stop();
    }

    if (await _healthOk(port) && _server == null) {
      return;
    }

    if (_server != null) {
      await stop();
    }

    final config = GrokProxyConfig.fromEnvironment(port: port);
    _store = GrokProxyStore(config);
    final server = await _tryBindServer(port);
    if (server == null) {
      _store = null;
      if (await _healthOk(port)) return;
      throw StateError('Grok proxy could not bind port $port');
    }
    _server = server;

    _server!.listen((request) async {
      try {
        await handleGrokProxyRequest(request, _store!);
      } catch (e) {
        try {
          request.response
            ..statusCode = 500
            ..write('{"error":"$e"}');
          await request.response.close();
        } catch (_) {}
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (await _healthOk(port)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    throw StateError('Grok proxy failed to start on port $port');
  }

  Future<HttpServer?> _tryBindServer(int port) async {
    try {
      return await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      if (await _healthOk(port)) return null;
      try {
        return await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: true,
        );
      } on SocketException {
        return null;
      }
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _store = null;
  }

  Future<bool> _healthOk(int port) async {
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:$port/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

}