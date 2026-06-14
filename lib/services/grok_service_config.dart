import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'grok_proxy_launcher.dart';
import 'grok_web_location_stub.dart'
    if (dart.library.html) 'grok_web_location_web.dart' as web_loc;

/// Resolves how the app talks to Grok on each platform.
class GrokServiceConfig {
  const GrokServiceConfig._();

  /// Optional remote proxy for web builds:
  /// `flutter build web --dart-define=GROK_PROXY_URL=https://your-proxy.example.com`
  static const _remoteProxyUrl = String.fromEnvironment('GROK_PROXY_URL', defaultValue: '');

  static const _localProxyUrl = 'http://127.0.0.1:${GrokProxyLauncher.defaultPort}';

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Synchronous fallback for non-web platforms and pre-init callers.
  static String resolveProxyBaseUrl({required String fallbackBaseUrl}) {
    if (!kIsWeb) return fallbackBaseUrl;
    final compileTime = _remoteProxyUrl.trim();
    if (compileTime.isNotEmpty) return _normalize(compileTime);
    return '';
  }

  /// Web: compile-time URL → baked asset config → local proxy health probe.
  static Future<String> resolveProxyBaseUrlAsync({required String fallbackBaseUrl}) async {
    if (!kIsWeb) return fallbackBaseUrl;

    final compileTime = _remoteProxyUrl.trim();
    if (compileTime.isNotEmpty) return _normalize(compileTime);

    final fromAsset = await _loadAssetProxyUrl();
    if (fromAsset.isNotEmpty) return _normalize(fromAsset);

    if (!web_loc.grokPageIsHttps() && await _proxyHealthy(_localProxyUrl)) {
      return _localProxyUrl;
    }

    return '';
  }

  static bool usesInBrowserConstrual(String proxyBaseUrl) =>
      kIsWeb && proxyBaseUrl.isEmpty;

  static int get defaultPort => GrokProxyLauncher.defaultPort;

  static Future<String> _loadAssetProxyUrl() async {
    try {
      final raw = await rootBundle.loadString('assets/config/grok_proxy.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return '${json['proxyUrl'] ?? ''}'.trim();
    } catch (_) {
      return '';
    }
  }

  static Future<bool> _proxyHealthy(String baseUrl) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}