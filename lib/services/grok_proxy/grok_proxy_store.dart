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
  GrokProxyStore(this.config, {http.Client? client}) : _client = client ?? http.Client();

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
      try {
        return await _fetchXPostPublic(uri);
      } catch (_) {
        // Fall through to authenticated X API v2 when signed in.
      }
      if (_accessToken != null) {
        return _fetchXPost(uri);
      }
      throw NarrativeLinkProxyException('fetch');
    }

    if (NarrativeLinkReader.isYouTubeUrl(urlString)) {
      try {
        return await _fetchYouTube(uri);
      } catch (_) {
        // Fall through to HTML/OG parsing.
      }
    }

    if (NarrativeLinkReader.isBlueskyUrl(urlString)) {
      try {
        return await _fetchBluesky(uri);
      } catch (_) {
        // Fall through to HTML/OG parsing.
      }
    }

    if (NarrativeLinkReader.isRedditUrl(urlString)) {
      try {
        return await _fetchReddit(uri);
      } catch (_) {
        // Fall through to HTML/OG parsing.
      }
    }

    if (NarrativeLinkReader.isMastodonUrl(urlString)) {
      try {
        return await _fetchMastodon(uri);
      } catch (_) {
        // Fall through to HTML/OG parsing.
      }
    }

    return _fetchHtmlNarrative(uri);
  }

  Future<Map<String, dynamic>> _fetchHtmlNarrative(Uri uri) async {
    final html = await NarrativeLinkReader.fetchHtmlForUri(uri, client: _client);
    final content = NarrativeLinkReader.parseHtml(html, uri.toString());
    final minChars = NarrativeLinkReader.minMeaningfulCharsForUri(uri);
    if (NarrativeLinkReader.meaningfulLength(content.narrative) < minChars) {
      throw NarrativeLinkProxyException('empty');
    }
    return {
      'url': content.url,
      'title': content.title,
      'narrative': content.narrative,
    };
  }

  /// Public X endpoints — no OAuth; works for most public posts.
  Future<Map<String, dynamic>> _fetchXPostPublic(Uri uri) async {
    final tweetId = NarrativeLinkReader.tweetIdFromUri(uri);
    if (tweetId == null) {
      throw NarrativeLinkProxyException('invalid');
    }

    Object? lastError;

    try {
      final oembedRes = await _client.get(
        Uri.https(
          'publish.twitter.com',
          '/oembed',
          {'url': uri.toString(), 'omit_script': '1', 'lang': 'en'},
        ),
      );
      if (oembedRes.statusCode == 200) {
        final json = jsonDecode(oembedRes.body) as Map<String, dynamic>;
        final text = NarrativeLinkReader.parseOembedTweetHtml('${json['html'] ?? ''}');
        if (text != null && text.isNotEmpty) {
          final handle = NarrativeLinkReader.authorHandleFromOembed(json);
          final author = handle != null ? '@$handle' : '${json['author_name'] ?? ''}'.trim();
          final narrative = author.isEmpty ? text : '$author: $text';
          if (NarrativeLinkReader.meaningfulLength(narrative) >=
              NarrativeLinkReader.minMeaningfulCharsForUri(uri)) {
            return {
              'url': uri.toString(),
              'title': 'X post $tweetId',
              'narrative': ScenarioInput.clamp(narrative),
            };
          }
        }
      } else {
        lastError = 'oembed HTTP ${oembedRes.statusCode}';
      }
    } catch (e) {
      lastError = e;
    }

    try {
      final syndicationRes = await _client.get(
        Uri.https(
          'cdn.syndication.twimg.com',
          '/tweet-result',
          {'id': tweetId, 'features': 'sfw', 'token': '1'},
        ),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': '*/*',
        },
      );
      if (syndicationRes.statusCode == 200) {
        final json = jsonDecode(syndicationRes.body) as Map<String, dynamic>;
        final text = '${json['text'] ?? ''}'.trim();
        if (text.isNotEmpty) {
          var author = '@x';
          final user = json['user'] as Map<String, dynamic>?;
          final screenName = '${user?['screen_name'] ?? ''}'.trim();
          if (screenName.isNotEmpty) author = '@$screenName';
          final narrative = '$author: $text';
          if (NarrativeLinkReader.meaningfulLength(narrative) >=
              NarrativeLinkReader.minMeaningfulCharsForUri(uri)) {
            return {
              'url': uri.toString(),
              'title': 'X post $tweetId',
              'narrative': ScenarioInput.clamp(narrative),
            };
          }
        }
      } else {
        lastError = 'syndication HTTP ${syndicationRes.statusCode}';
      }
    } catch (e) {
      lastError = e;
    }

    throw NarrativeLinkProxyException('fetch', cause: lastError);
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

  Future<Map<String, dynamic>> _fetchYouTube(Uri uri) async {
    final videoId = NarrativeLinkReader.youtubeIdFromUri(uri);
    if (videoId == null) {
      throw NarrativeLinkProxyException('invalid');
    }

    var title = 'YouTube video $videoId';
    var author = '';
    final oembedRes = await _client.get(
      Uri.https(
        'www.youtube.com',
        '/oembed',
        {'url': uri.toString(), 'format': 'json'},
      ),
    );
    if (oembedRes.statusCode == 200) {
      final json = jsonDecode(oembedRes.body) as Map<String, dynamic>;
      title = '${json['title'] ?? title}'.trim();
      author = '${json['author_name'] ?? ''}'.trim();
    }

    var description = '';
    try {
      final html = await NarrativeLinkReader.fetchHtmlForUri(uri, client: _client);
      description = NarrativeLinkReader.parseHtml(html, uri.toString()).narrative;
    } catch (_) {}

    final parts = <String>[];
    if (author.isNotEmpty) parts.add(author);
    if (title.isNotEmpty) parts.add(title);
    if (description.isNotEmpty) parts.add(description);
    final narrative = parts.join('\n\n').trim();
    if (NarrativeLinkReader.meaningfulLength(narrative) <
        NarrativeLinkReader.minMeaningfulCharsForUri(uri)) {
      throw NarrativeLinkProxyException('empty');
    }

    return {
      'url': uri.toString(),
      'title': title,
      'narrative': ScenarioInput.clamp(narrative),
    };
  }

  Future<Map<String, dynamic>> _fetchBluesky(Uri uri) async {
    final ref = NarrativeLinkReader.blueskyPostFromUri(uri);
    if (ref == null) {
      throw NarrativeLinkProxyException('invalid');
    }

    final resolveRes = await _client.get(
      Uri.https(
        'public.api.bsky.app',
        '/xrpc/com.atproto.identity.resolveHandle',
        {'handle': ref.handle},
      ),
    );
    if (resolveRes.statusCode != 200) {
      throw NarrativeLinkProxyException('fetch', cause: resolveRes.body);
    }

    final did =
        '${(jsonDecode(resolveRes.body) as Map<String, dynamic>)['did'] ?? ''}'.trim();
    if (did.isEmpty) {
      throw NarrativeLinkProxyException('fetch');
    }

    final atUri = 'at://$did/app.bsky.bsky.feed.post/${ref.rkey}';
    final postRes = await _client.get(
      Uri.https(
        'public.api.bsky.app',
        '/xrpc/app.bsky.feed.getPosts',
        {'uris': atUri},
      ),
    );
    if (postRes.statusCode != 200) {
      throw NarrativeLinkProxyException('fetch', cause: postRes.body);
    }

    final posts = (jsonDecode(postRes.body) as Map<String, dynamic>)['posts'];
    if (posts is! List || posts.isEmpty) {
      throw NarrativeLinkProxyException('empty');
    }

    final post = posts.first as Map<String, dynamic>;
    final record = post['record'] as Map<String, dynamic>?;
    final text = '${record?['text'] ?? ''}'.trim();
    if (text.isEmpty) {
      throw NarrativeLinkProxyException('empty');
    }

    var author = '@${ref.handle}';
    final authorObj = post['author'] as Map<String, dynamic>?;
    final handle = '${authorObj?['handle'] ?? ''}'.trim();
    if (handle.isNotEmpty) author = '@$handle';

    final narrative = '$author: $text';
    return {
      'url': uri.toString(),
      'title': 'Bluesky post',
      'narrative': ScenarioInput.clamp(narrative),
    };
  }

  Future<Map<String, dynamic>> _fetchReddit(Uri uri) async {
    final jsonPath = NarrativeLinkReader.redditJsonPath(uri);
    if (jsonPath == null) {
      throw NarrativeLinkProxyException('invalid');
    }

    final jsonUri = uri.replace(path: jsonPath, query: '', fragment: '');
    final res = await _client.get(
      jsonUri,
      headers: {
        'User-Agent': 'Evolve/1.0 (narrative reader)',
        'Accept': 'application/json',
      },
    );
    if (res.statusCode == 401 || res.statusCode == 403 || res.statusCode == 429) {
      throw NarrativeLinkProxyException('blocked', statusCode: res.statusCode);
    }
    if (res.statusCode != 200) {
      throw NarrativeLinkProxyException('fetch', cause: res.body);
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) {
      throw NarrativeLinkProxyException('empty');
    }

    final listing = decoded.first as Map<String, dynamic>;
    final children = listing['data']?['children'];
    if (children is! List || children.isEmpty) {
      throw NarrativeLinkProxyException('empty');
    }

    final postData = (children.first as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    final title = '${postData?['title'] ?? ''}'.trim();
    final selftext = '${postData?['selftext'] ?? ''}'.trim();
    final author = '${postData?['author'] ?? ''}'.trim();

    final parts = <String>[];
    if (author.isNotEmpty) parts.add('u/$author');
    if (title.isNotEmpty) parts.add(title);
    if (selftext.isNotEmpty) parts.add(selftext);
    final narrative = parts.join('\n\n').trim();
    if (NarrativeLinkReader.meaningfulLength(narrative) <
        NarrativeLinkReader.minMeaningfulCharsForUri(uri)) {
      throw NarrativeLinkProxyException('empty');
    }

    return {
      'url': uri.toString(),
      'title': title.isEmpty ? 'Reddit post' : title,
      'narrative': ScenarioInput.clamp(narrative),
    };
  }

  Future<Map<String, dynamic>> _fetchMastodon(Uri uri) async {
    final res = await _client.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (compatible; Evolve/1.0; +https://github.com/rgsneddon/evolve)',
        'Accept': 'application/json',
      },
    );
    if (res.statusCode == 401 || res.statusCode == 403 || res.statusCode == 429) {
      throw NarrativeLinkProxyException('blocked', statusCode: res.statusCode);
    }
    if (res.statusCode != 200) {
      throw NarrativeLinkProxyException('fetch', cause: res.body);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final contentHtml = '${json['content'] ?? ''}'.trim();
    if (contentHtml.isEmpty) {
      throw NarrativeLinkProxyException('empty');
    }

    final text = NarrativeLinkReader.parseHtml(
      '<body>$contentHtml</body>',
      uri.toString(),
    ).narrative;

    var author = '';
    final acct = json['account'] as Map<String, dynamic>?;
    final username = '${acct?['username'] ?? ''}'.trim();
    final domain = '${acct?['acct'] ?? username}'.trim();
    if (domain.isNotEmpty) author = '@$domain';

    final narrative = author.isEmpty ? text : '$author: $text';
    if (NarrativeLinkReader.meaningfulLength(narrative) <
        NarrativeLinkReader.minMeaningfulCharsForUri(uri)) {
      throw NarrativeLinkProxyException('empty');
    }

    return {
      'url': uri.toString(),
      'title': 'Mastodon post',
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