import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/grok_session.dart';

class GrokLoginStart {
  const GrokLoginStart({
    required this.authorizeUrl,
    required this.redirectUri,
    this.clientId = '',
    this.mock = false,
  });

  final Uri authorizeUrl;
  final String redirectUri;
  final String clientId;
  final bool mock;
}

class GrokAuthException implements Exception {
  GrokAuthException(this.code, {this.message});

  final String code;
  final String? message;

  @override
  String toString() => 'GrokAuthException($code${message != null ? ': $message' : ''})';
}

/// Talks to the local Grok proxy for X OAuth and premium verification.
class GrokAuthClient {
  const GrokAuthClient({
    this.baseUrl = 'http://127.0.0.1:8787',
    http.Client? client,
  }) : _client = client;

  final String baseUrl;
  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<bool> isProxyReachable() async {
    try {
      final res = await _http.get(_uri('/health')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<GrokSession> fetchStatus() async {
    final res = await _http.get(_uri('/auth/status')).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw GrokAuthException('status', message: res.body);
    }
    return GrokSession.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Dev mock sign-in — avoids the browser callback URL (can block behind queued requests).
  Future<GrokSession> completeMockLogin() async {
    final res = await _http
        .post(_uri('/auth/mock-complete'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw GrokAuthException('mock_login', message: res.body);
    }
    return GrokSession.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Hit the local OAuth callback (mock mode completes without a browser tab).
  Future<void> triggerOAuthCallback(Uri callbackUri) async {
    final res = await _http.get(callbackUri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw GrokAuthException('callback', message: res.body);
    }
  }

  static bool isEmbeddedMockCallback(Uri authorize) {
    final local = authorize.host == '127.0.0.1' || authorize.host == 'localhost';
    return local &&
        authorize.path == '/auth/callback' &&
        authorize.queryParameters['code'] == 'mock';
  }

  Future<GrokLoginStart> beginLogin() async {
    final res = await _http.get(_uri('/auth/login')).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw GrokAuthException('login', message: res.body);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final url = json['authorizeUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw GrokAuthException('login', message: 'Missing authorizeUrl');
    }
    final authorizeUrl = Uri.parse(url);
    final clientId = '${json['clientId'] ?? ''}'.trim();
    final urlClientId = authorizeUrl.queryParameters['client_id']?.trim() ?? '';
    if (clientId.isNotEmpty &&
        urlClientId.isNotEmpty &&
        clientId != urlClientId) {
      throw GrokAuthException(
        'login',
        message: 'client_id mismatch (config vs authorize URL)',
      );
    }
    return GrokLoginStart(
      authorizeUrl: authorizeUrl,
      redirectUri: '${json['redirectUri'] ?? ''}',
      clientId: clientId.isNotEmpty ? clientId : urlClientId,
      mock: json['mock'] == true,
    );
  }

  Future<void> logout() async {
    await _http.post(_uri('/auth/logout')).timeout(const Duration(seconds: 8));
  }

  /// Poll until connected (and premium when [requirePremium]) or timeout.
  Future<GrokSession> waitForSession({
    Duration timeout = const Duration(minutes: 2),
    Duration interval = const Duration(seconds: 1),
    bool requirePremium = true,
  }) async {
    final deadline = DateTime.now().add(timeout);
    GrokSession last = const GrokSession();
    while (DateTime.now().isBefore(deadline)) {
      last = await fetchStatus();
      if (last.oauthError.isNotEmpty) return last;
      if (last.connected && (!requirePremium || last.premium)) return last;
      await Future<void>.delayed(interval);
    }
    return last;
  }
}