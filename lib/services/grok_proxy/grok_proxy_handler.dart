import 'dart:convert';
import 'dart:io';

import 'grok_proxy_store.dart';

Future<void> handleGrokProxyRequest(HttpRequest request, GrokProxyStore store) async {
  _cors(request);
  if (request.method.toUpperCase() == 'OPTIONS') {
    request.response.statusCode = 204;
    await request.response.close();
    return;
  }

  final path = request.uri.path;
  final method = request.method.toUpperCase();

  if (path == '/health' && method == 'GET') {
    return _json(request, 200, {'ok': true});
  }
  if (path == '/auth/status' && method == 'GET') {
    return _json(request, 200, store.statusJson());
  }
  if (path == '/auth/login' && method == 'GET') {
    final url = await store.authorizeUrl();
    return _json(request, 200, {
      'authorizeUrl': url,
      'redirectUri': store.redirectUri,
      'clientId': store.clientId,
      'mock': store.mock,
    });
  }
  if (path == '/auth/mock-complete' && method == 'POST') {
    await store.completeOAuth('mock', 'mock');
    return _json(request, 200, store.statusJson());
  }
  if (path == '/auth/callback' && method == 'GET') {
    final oauthError = request.uri.queryParameters['error'];
    if (oauthError != null) {
      final description =
          request.uri.queryParameters['error_description'] ?? oauthError;
      store.recordOAuthError(description);
      return _text(
        request,
        400,
        '<html><body><h2>X sign-in failed</h2><p>$description</p>'
        '<p>Check console.x.com: OAuth 2.0 enabled, app type Native App, '
        'callback URL exactly <code>${store.redirectUri}</code> (use 127.0.0.1, not localhost).</p>'
        '</body></html>',
        contentType: 'text/html',
      );
    }

    final code = request.uri.queryParameters['code'];
    final state = request.uri.queryParameters['state'];
    if (code == null) {
      return _text(request, 400, 'Missing code');
    }
    try {
      await store.completeOAuth(code, state);
    } catch (e) {
      final message = '$e';
      store.recordOAuthError(message);
      return _text(
        request,
        500,
        '<html><body><h2>X sign-in failed</h2><p>$message</p>'
        '<p>Return to Evolve and try again.</p></body></html>',
        contentType: 'text/html',
      );
    }
    return _text(
      request,
      200,
      _oauthSuccessHtml(),
      contentType: 'text/html',
    );
  }
  if (path == '/auth/logout' && method == 'POST') {
    store.logout();
    return _json(request, 200, {'ok': true});
  }
  if (path == '/construe' && method == 'POST') {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body) as Map<String, dynamic>;
    if (!store.canConstrue) {
      return _json(request, 401, {'error': 'premium_required'});
    }
    final result = await store.construe(payload);
    return _json(request, 200, result);
  }
  if (path == '/narrative/fetch' && method == 'POST') {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final url = '${payload['url'] ?? ''}'.trim();
    try {
      final result = await store.fetchNarrativeLink(url);
      return _json(request, 200, result);
    } on NarrativeLinkProxyException catch (e) {
      return _json(request, e.statusCode, {'error': e.code});
    }
  }

  _json(request, 404, {'error': 'not_found'});
}

String _oauthSuccessHtml() => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>X connected</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; color: #111; }
    p { color: #444; }
  </style>
  <script>
    (function () {
      try {
        if (window.opener) {
          window.opener.postMessage('evolve-x-oauth-complete', '*');
        }
      } catch (e) {}
      setTimeout(function () {
        try { window.close(); } catch (e) {}
      }, 600);
    })();
  </script>
</head>
<body>
  <h2>X connected</h2>
  <p>Return to Evolve Chronoflux — this tab will close automatically.</p>
</body>
</html>
''';

void _cors(HttpRequest request) {
  request.response.headers
    ..add('Access-Control-Allow-Origin', '*')
    ..add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..add('Access-Control-Allow-Headers', 'Content-Type');
}

Future<void> _json(HttpRequest request, int status, Map<String, dynamic> body) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

Future<void> _text(
  HttpRequest request,
  int status,
  String body, {
  String? contentType,
}) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.parse(contentType ?? 'text/plain')
    ..write(body);
  await request.response.close();
}