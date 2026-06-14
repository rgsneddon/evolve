import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../models/scenario_input.dart';
import '../narrative_link_reader.dart';
import 'grok_construct_prompt.dart';
import 'grok_proxy_config.dart';
import 'grok_proxy_heuristic.dart';

/// OAuth session + construal logic shared by CLI proxy and embedded server.
class GrokProxyStore {
  GrokProxyStore(this.config) : _client = http.Client();

  final GrokProxyConfig config;
  final http.Client _client;

  String? _accessToken;
  String? _screenName;
  String? _displayName;
  bool _premium = false;
  String? _codeVerifier;
  String? _oauthState;
  String? _lastOAuthError;

  bool get mock => config.mock;

  String get redirectUri => config.redirectUri;

  Map<String, dynamic> statusJson() => {
        'connected': _accessToken != null,
        'premium': _premium,
        'screenName': _screenName ?? '',
        'displayName': _displayName ?? '',
        'mock': config.mock,
        if (_lastOAuthError != null) 'oauthError': _lastOAuthError,
      };

  void recordOAuthError(String message) {
    _lastOAuthError = message;
  }

  bool get canConstrue => _accessToken != null && _premium;

  void logout() {
    _accessToken = null;
    _screenName = null;
    _displayName = null;
    _premium = false;
  }

  Future<String> authorizeUrl() async {
    if (config.mock) {
      return '${config.redirectUri}?code=mock&state=mock';
    }

    _lastOAuthError = null;
    _codeVerifier = _randomVerifier();
    final challenge = _codeChallenge(_codeVerifier!);
    _oauthState = _randomVerifier().substring(0, 16);
    final clientId = config.xClientId!;
    return Uri.https('x.com', '/i/oauth2/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': config.redirectUri,
      'scope': 'tweet.read users.read offline.access',
      'state': _oauthState!,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    }).toString();
  }

  Future<void> completeOAuth(String code, String? state) async {
    if (config.mock || code == 'mock') {
      _accessToken = 'mock-token';
      _screenName = 'evolve_mock';
      _displayName = 'Evolve Mock User';
      _premium = true;
      return;
    }
    if (state != _oauthState) {
      throw StateError('OAuth state mismatch');
    }

    final clientId = config.xClientId!;
    final clientSecret = config.xClientSecret ?? '';

    final tokenRes = await _client.post(
      Uri.parse('https://api.x.com/2/oauth2/token'),
      headers: tokenExchangeHeaders(clientId, clientSecret),
      body: tokenExchangeBody(
        code: code,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUri: config.redirectUri,
        codeVerifier: _codeVerifier!,
      ),
    );

    if (tokenRes.statusCode != 200) {
      final message = 'Token exchange failed: ${tokenRes.body}';
      _lastOAuthError = message;
      throw StateError(message);
    }

    final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    _accessToken = tokenJson['access_token'] as String?;

    final meRes = await _client.get(
      Uri.parse(
        'https://api.x.com/2/users/me?user.fields=subscription_type,verified_type,name,username',
      ),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (meRes.statusCode != 200) {
      final message = 'User lookup failed: ${meRes.body}';
      _lastOAuthError = message;
      throw StateError(message);
    }

    final data = (jsonDecode(meRes.body) as Map<String, dynamic>)['data']
        as Map<String, dynamic>?;
    _screenName = '${data?['username'] ?? ''}';
    _displayName = '${data?['name'] ?? _screenName}';
    final sub = '${data?['subscription_type'] ?? ''}'.toLowerCase();
    _premium = sub.contains('premium');
  }

  /// Server-side narrative fetch — bypasses browser CORS; X posts use the signed-in OAuth token.
  Future<Map<String, dynamic>> fetchNarrativeLink(String urlString) async {
    final uri = NarrativeLinkReader.normalizeUrl(urlString);
    if (uri == null) {
      throw NarrativeLinkProxyException('invalid');
    }

    if (NarrativeLinkReader.isXUrl(urlString)) {
      if (_accessToken == null) {
        throw NarrativeLinkProxyException('x_auth_required', statusCode: 401);
      }
      return _fetchXPost(uri);
    }

    final html = await NarrativeLinkReader.fetchHtmlForUri(uri, client: _client);
    final content = NarrativeLinkReader.parseHtml(html, uri.toString());
    if (NarrativeLinkReader.meaningfulLength(content.narrative) <
        NarrativeLinkReader.minMeaningfulChars) {
      throw NarrativeLinkProxyException('empty');
    }
    return {
      'url': content.url,
      'title': content.title,
      'narrative': content.narrative,
    };
  }

  Future<Map<String, dynamic>> _fetchXPost(Uri uri) async {
    final tweetId = NarrativeLinkReader.tweetIdFromUri(uri);
    if (tweetId == null) {
      throw NarrativeLinkProxyException('invalid');
    }

    final apiUri = Uri.https(
      'api.x.com',
      '/2/tweets/$tweetId',
      {
        'tweet.fields': 'text,created_at,author_id',
        'expansions': 'author_id',
        'user.fields': 'username,name',
      },
    );

    final res = await _client.get(
      apiUri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw NarrativeLinkProxyException('x_auth_required', statusCode: 401);
    }
    if (res.statusCode == 429) {
      throw NarrativeLinkProxyException('blocked', statusCode: 429);
    }
    if (res.statusCode != 200) {
      throw NarrativeLinkProxyException('fetch', cause: res.body);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    final text = '${data?['text'] ?? ''}'.trim();
    if (text.isEmpty) {
      throw NarrativeLinkProxyException('empty');
    }

    var author = '@x';
    final users = json['includes']?['users'];
    if (users is List && users.isNotEmpty) {
      final user = users.first as Map<String, dynamic>;
      final username = '${user['username'] ?? ''}'.trim();
      if (username.isNotEmpty) author = '@$username';
    }

    final narrative = '$author: $text';
    return {
      'url': uri.toString(),
      'title': 'X post $tweetId',
      'narrative': ScenarioInput.clamp(narrative),
    };
  }

  Future<Map<String, dynamic>> construe(Map<String, dynamic> payload) async {
    final apiKey = config.xaiApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        return await _construeViaXai(apiKey, payload);
      } catch (_) {
        // fall through to heuristic
      }
    }

    return _heuristicPayload(payload);
  }

  Map<String, dynamic> _heuristicPayload(Map<String, dynamic> payload) =>
      GrokProxyHeuristic.suggest(payload, mock: config.mock);

  Future<Map<String, dynamic>> _construeViaXai(
    String apiKey,
    Map<String, dynamic> payload,
  ) async {
    final model = config.xaiConstrualModel;
    final res = await _client.post(
      Uri.parse('https://api.x.ai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': GrokConstructPrompt.systemMessage},
          {'role': 'user', 'content': GrokConstructPrompt.userMessage(payload)},
        ],
        'temperature': 0.35,
        'search_parameters': {
          'mode': 'on',
          'max_search_results': 10,
          'return_citations': false,
        },
      }),
    );

    if (res.statusCode != 200) {
      throw StateError(res.body);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (json['choices'] as List).first['message']['content'] as String;
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw StateError('No JSON in Grok construal response');
    }
    final parsed = jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;
    final question = '${payload['posedQuestion'] ?? ''}';
    final fields = GrokConstructPrompt.sanitizeFields(parsed, question);

    final hasAny = fields.values.any((v) => v.isNotEmpty);
    if (!hasAny) {
      throw StateError('Grok returned only question echoes — retry or check search access');
    }

    return {
      ...fields,
      'provenance': 'grok-live',
    };
  }

  String _randomVerifier() {
    final r = Random.secure();
    return List.generate(64, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}

/// X OAuth token exchange — confidential clients use Basic Auth; public clients use PKCE + client_id.
Map<String, String> tokenExchangeHeaders(String clientId, String clientSecret) {
  final headers = <String, String>{
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  if (clientSecret.isNotEmpty) {
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    headers['Authorization'] = 'Basic $credentials';
  }
  return headers;
}

Map<String, String> tokenExchangeBody({
  required String code,
  required String clientId,
  required String clientSecret,
  required String redirectUri,
  required String codeVerifier,
}) {
  final body = <String, String>{
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': redirectUri,
    'code_verifier': codeVerifier,
  };
  if (clientSecret.isEmpty) {
    body['client_id'] = clientId;
  }
  return body;
}

/// Narrative fetch errors returned by the Grok proxy API.
class NarrativeLinkProxyException implements Exception {
  NarrativeLinkProxyException(this.code, {this.statusCode = 400, this.cause});

  final String code;
  final int statusCode;
  final Object? cause;

  @override
  String toString() => 'NarrativeLinkProxyException($code)';
}