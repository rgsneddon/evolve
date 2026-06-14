// ignore_for_file: avoid_print
/// Standalone Grok proxy (optional — the app auto-starts an embedded proxy on Use).
///
/// Run: dart run tool/grok_proxy.dart
/// Env: X_CLIENT_ID, X_CLIENT_SECRET (optional), XAI_API_KEY (optional), GROK_PROXY_MOCK=1
///      GROK_PROXY_PUBLIC_URL (HTTPS callback base for cloud deploy)
///      GROK_PROXY_BIND (default 127.0.0.1; use 0.0.0.0 for containers)
import 'dart:io';

import 'package:evolve/services/grok_proxy/grok_proxy_config.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_handler.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_store.dart';

void main() async {
  final port = int.tryParse(Platform.environment['GROK_PROXY_PORT'] ?? '') ?? 8787;
  final bindHost = Platform.environment['GROK_PROXY_BIND'] ?? '127.0.0.1';
  final config = GrokProxyConfig.fromEnvironment(port: port);
  final store = GrokProxyStore(config);
  final address = bindHost == '0.0.0.0'
      ? InternetAddress.anyIPv4
      : InternetAddress.tryParse(bindHost) ?? InternetAddress.loopbackIPv4;
  final server = await HttpServer.bind(address, port);
  final public = config.publicBaseUrl?.trim();
  final advertised = (public != null && public.isNotEmpty) ? public : 'http://127.0.0.1:$port';
  print('Grok proxy listening on http://${address.address}:$port (mock=${config.mock})');
  print('OAuth redirect: ${config.redirectUri}');
  print('Advertised URL: $advertised');

  server.listen((request) async {
    try {
      await handleGrokProxyRequest(request, store);
    } catch (e, st) {
      print('Error: $e\n$st');
      try {
        request.response
          ..statusCode = 500
          ..write('{"error":"$e"}');
        await request.response.close();
      } catch (_) {}
    }
  });
}