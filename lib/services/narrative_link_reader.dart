import 'dart:convert';

import 'package:http/http.dart' as http;

import 'platform_detect_stub.dart'
    if (dart.library.io) 'platform_detect_io.dart'
    if (dart.library.html) 'platform_detect_web.dart' as platform_detect;

/// Text extracted from a narrative URL for SCS analysis.
class NarrativeLinkContent {
  const NarrativeLinkContent({
    required this.url,
    required this.title,
    required this.narrative,
  });

  final String url;
  final String title;
  final String narrative;
}

/// Fetches and parses public narrative pages for cohesion scoring.
class NarrativeLinkReader {
  const NarrativeLinkReader({http.Client? client}) : _client = client;

  static const minMeaningfulChars = 80;
  static const minMeaningfulCharsShortForm = 20;
  static const minMeaningfulCharsSocialOg = 30;

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  Future<NarrativeLinkContent> fetch(
    String urlString, {
    String? proxyBaseUrl,
  }) async {
    final proxy = proxyBaseUrl?.trim() ?? '';
    if (proxy.isNotEmpty) {
      return fetchViaProxy(proxy, urlString);
    }

    final uri = normalizeUrl(urlString);
    if (uri == null) {
      throw NarrativeLinkException('invalid');
    }
    if (requiresProxyFetch(uri)) {
      throw NarrativeLinkException('blocked', cause: uri.host);
    }

    Object? lastError;
    var sawBlocked = false;
    for (final fetchUri in _fetchCandidates(uri)) {
      for (final headers in _headerVariants()) {
        try {
          final response = await _http
              .get(fetchUri, headers: headers)
              .timeout(const Duration(seconds: 25));
          if (response.statusCode == 401 ||
              response.statusCode == 403 ||
              response.statusCode == 429) {
            sawBlocked = true;
            lastError = 'HTTP ${response.statusCode}';
            continue;
          }
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final content = parseHtml(response.body, uri.toString());
            if (meaningfulLength(content.narrative) < minMeaningfulChars) {
              lastError = 'empty';
              continue;
            }
            return content;
          }
          lastError = 'HTTP ${response.statusCode}';
        } catch (e) {
          lastError = e;
        }
      }
    }

    if (lastError == 'empty') {
      throw NarrativeLinkException('empty', cause: lastError);
    }
    if (sawBlocked) {
      throw NarrativeLinkException('blocked', cause: lastError);
    }
    throw NarrativeLinkException('fetch', cause: lastError);
  }

  /// Fetches narrative text through the Grok proxy (web CORS bypass + X OAuth).
  Future<NarrativeLinkContent> fetchViaProxy(String proxyBaseUrl, String urlString) async {
    final base = proxyBaseUrl.endsWith('/')
        ? proxyBaseUrl.substring(0, proxyBaseUrl.length - 1)
        : proxyBaseUrl;
    final uri = normalizeUrl(urlString);
    if (uri == null) {
      throw NarrativeLinkException('invalid');
    }

    final response = await _http
        .post(
          Uri.parse('$base/narrative/fetch'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': uri.toString()}),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw NarrativeLinkException('fetch', cause: response.statusCode);
    }

    final error = '${json['error'] ?? ''}'.trim();
    if (error.isNotEmpty || response.statusCode >= 400) {
      throw NarrativeLinkException(
        error.isNotEmpty ? error : 'fetch',
        cause: response.statusCode,
      );
    }

    final narrative = '${json['narrative'] ?? ''}'.trim();
    if (meaningfulLength(narrative) < minMeaningfulCharsForUri(uri)) {
      throw NarrativeLinkException('empty');
    }

    return NarrativeLinkContent(
      url: '${json['url'] ?? uri}'.trim().isEmpty ? uri.toString() : '${json['url']}',
      title: '${json['title'] ?? ''}'.trim().isEmpty
          ? _titleFromUrl(uri.toString())
          : '${json['title']}',
      narrative: narrative,
    );
  }

  static bool isXUrl(String urlString) {
    final uri = normalizeUrl(urlString);
    return uri != null && _isXHost(uri);
  }

  /// True for X/Twitter and other social hosts that need the Grok proxy (or fail direct fetch).
  static bool isSocialMediaUrl(String urlString) {
    final uri = normalizeUrl(urlString);
    return uri != null && requiresProxyFetch(uri);
  }

  static bool requiresProxyFetch(Uri uri) =>
      _isXHost(uri) || _isSocialMediaHost(uri) || _isMastodonStatusUrl(uri);

  static int minMeaningfulCharsForUri(Uri uri) {
    if (_isXHost(uri) ||
        _isBlueskyHost(uri) ||
        _isMastodonStatusUrl(uri) ||
        _redditPath(uri).isNotEmpty) {
      return minMeaningfulCharsShortForm;
    }
    if (_isSocialMediaHost(uri)) {
      return minMeaningfulCharsSocialOg;
    }
    return minMeaningfulChars;
  }

  static bool isYouTubeUrl(String urlString) {
    final uri = normalizeUrl(urlString);
    return uri != null && _isYouTubeHost(uri.host);
  }

  static bool isBlueskyUrl(String urlString) {
    final uri = normalizeUrl(urlString);
    return uri != null && _isBlueskyHost(uri);
  }

  static bool isRedditUrl(String urlString) {
    final uri = normalizeUrl(urlString);
    return uri != null && _isRedditHost(uri.host);
  }

  static bool isMastodonUrl(String urlString) {
    final uri = normalizeUrl(urlString);
    return uri != null && _isMastodonStatusUrl(uri);
  }

  static String? youtubeIdFromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      return id.isEmpty ? null : id.split('?').first;
    }
    if (_isYouTubeHost(host)) {
      final v = uri.queryParameters['v']?.trim() ?? '';
      if (v.isNotEmpty) return v;
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
        final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
        return id.isEmpty ? null : id;
      }
    }
    return null;
  }

  static BlueskyPostRef? blueskyPostFromUri(Uri uri) {
    if (!_isBlueskyHost(uri)) return null;
    final segments = uri.pathSegments;
    final profileIdx = segments.indexOf('profile');
    if (profileIdx < 0 || profileIdx + 3 >= segments.length) return null;
    if (segments[profileIdx + 2] != 'post') return null;
    final handle = segments[profileIdx + 1].trim();
    final rkey = segments[profileIdx + 3].trim();
    if (handle.isEmpty || rkey.isEmpty) return null;
    return BlueskyPostRef(handle: handle, rkey: rkey);
  }

  static String? redditJsonPath(Uri uri) {
    if (!_isRedditHost(uri.host)) return null;
    var path = uri.path;
    if (path.isEmpty || path == '/') return null;
    if (path.endsWith('.json')) return path;
    return '$path.json';
  }

  static String? mastodonStatusPath(Uri uri) {
    if (!_isMastodonStatusUrl(uri)) return null;
    return uri.path;
  }

  static String? tweetIdFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final statusIdx = segments.indexOf('status');
    if (statusIdx < 0 || statusIdx + 1 >= segments.length) return null;
    final id = segments[statusIdx + 1].replaceAll(RegExp(r'\D'), '');
    return id.isEmpty ? null : id;
  }

  /// Tweet body from X publish.oembed HTML (`blockquote` → `p`).
  static String? parseOembedTweetHtml(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return null;
    final pMatch = RegExp(
      r'<p[^>]*>([\s\S]*?)</p>',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (pMatch != null) {
      final text = _decodeEntities(_stripTags(pMatch.group(1) ?? '')).trim();
      if (text.isNotEmpty) return text;
    }
    final fallback = _stripHtml(trimmed);
    return fallback.isEmpty ? null : fallback;
  }

  static String? authorHandleFromOembed(Map<String, dynamic> json) {
    final authorUrl = '${json['author_url'] ?? ''}'.trim();
    final uri = Uri.tryParse(authorUrl);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final handle = uri.pathSegments.last.trim();
    return handle.isEmpty ? null : handle;
  }

  /// Server-side HTML fetch (Grok proxy) — no browser CORS limits.
  static Future<String> fetchHtmlForUri(
    Uri uri, {
    required http.Client client,
  }) async {
    Object? lastError;
    for (final fetchUri in _directFetchCandidates(uri)) {
      for (final headers in _headerVariants()) {
        try {
          final response = await client
              .get(fetchUri, headers: headers)
              .timeout(const Duration(seconds: 25));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return response.body;
          }
          lastError = 'HTTP ${response.statusCode}';
        } catch (e) {
          lastError = e;
        }
      }
    }
    throw NarrativeLinkException('fetch', cause: lastError);
  }

  static List<Uri> _directFetchCandidates(Uri uri) {
    final seen = <String>{};
    final out = <Uri>[];

    void add(Uri? candidate) {
      if (candidate == null) return;
      final key = candidate.toString();
      if (seen.add(key)) out.add(candidate);
    }

    final https = uri.scheme == 'http'
        ? uri.replace(scheme: 'https', port: uri.hasPort ? uri.port : null)
        : uri;
    add(https);
    add(uri);

    final host = https.host;
    if (!host.startsWith('www.')) {
      add(https.replace(host: 'www.$host'));
    } else if (host.length > 4) {
      add(https.replace(host: host.substring(4)));
    }
    return out;
  }

  static Uri? normalizeUrl(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(t)) {
      t = 'https://$t';
    }
    final uri = Uri.tryParse(t);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  static bool get _isMobilePlatform =>
      !platform_detect.platformIsWeb && platform_detect.platformIsMobile;

  static bool _isXHost(Uri uri) {
    final h = uri.host.toLowerCase();
    return h == 'x.com' ||
        h == 'twitter.com' ||
        h == 'mobile.twitter.com' ||
        h.endsWith('.x.com') ||
        h.endsWith('.twitter.com');
  }

  static bool _isBlueskyHost(Uri uri) {
    final h = uri.host.toLowerCase();
    return h == 'bsky.app' ||
        h.endsWith('.bsky.app') ||
        h == 'bsky.social' ||
        h.endsWith('.bsky.social');
  }

  static bool _isYouTubeHost(String host) {
    final h = host.toLowerCase();
    return h == 'youtube.com' ||
        h == 'www.youtube.com' ||
        h == 'm.youtube.com' ||
        h == 'youtu.be' ||
        h.endsWith('.youtube.com');
  }

  static bool _isRedditHost(String host) {
    final h = host.toLowerCase();
    return h == 'reddit.com' ||
        h == 'www.reddit.com' ||
        h == 'old.reddit.com' ||
        h.endsWith('.reddit.com');
  }

  static bool _isSocialMediaHost(Uri uri) {
    final h = uri.host.toLowerCase();
    if (_isYouTubeHost(h) || _isRedditHost(h) || _isBlueskyHost(uri)) return true;

    const hosts = {
      'facebook.com',
      'www.facebook.com',
      'm.facebook.com',
      'fb.com',
      'www.fb.com',
      'instagram.com',
      'www.instagram.com',
      'threads.net',
      'www.threads.net',
      'linkedin.com',
      'www.linkedin.com',
      'tiktok.com',
      'www.tiktok.com',
      'vm.tiktok.com',
      'pinterest.com',
      'www.pinterest.com',
      't.co',
    };

    if (hosts.contains(h)) return true;

    const suffixes = [
      '.facebook.com',
      '.instagram.com',
      '.threads.net',
      '.linkedin.com',
      '.tiktok.com',
    ];
    return suffixes.any(h.endsWith);
  }

  static String _redditPath(Uri uri) {
    if (!_isRedditHost(uri.host)) return '';
    final path = uri.path;
    if (!path.contains('/comments/')) return '';
    return path;
  }

  static bool _isMastodonStatusUrl(Uri uri) {
    final path = uri.path;
    if (path.contains('/statuses/')) return true;
    final statusMatch = RegExp(r'^/@[^/]+/\d+').hasMatch(path);
    return statusMatch;
  }

  static List<Uri> _fetchCandidates(Uri uri) {
    final seen = <String>{};
    final out = <Uri>[];

    void add(Uri? candidate) {
      if (candidate == null) return;
      final key = candidate.toString();
      if (seen.add(key)) out.add(candidate);
    }

    final https =
        uri.scheme == 'http' ? uri.replace(scheme: 'https', port: uri.hasPort ? uri.port : null) : uri;
    add(https);
    if (!_isMobilePlatform || uri.scheme == 'http') {
      add(uri);
    }

    final host = https.host;
    if (!host.startsWith('www.')) {
      add(https.replace(host: 'www.$host'));
    } else if (host.length > 4) {
      add(https.replace(host: host.substring(4)));
    }

    if (platform_detect.platformIsWeb) {
      add(Uri.parse(
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(https.toString())}',
      ));
    }

    if (_isMobilePlatform) {
      return out.where((u) => u.scheme == 'https').toList();
    }
    return out;
  }

  static List<Map<String, String>> _headerVariants() => [
        _browserHeaders(mobile: _isMobilePlatform),
        _browserHeaders(mobile: false),
      ];

  static Map<String, String> _browserHeaders({required bool mobile}) => {
        'User-Agent': mobile ? _mobileUserAgent : _desktopUserAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-GB,en;q=0.9',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  static NarrativeLinkContent parseHtml(String html, String url) {
    final title = _extractJsonLdHeadline(html) ??
        _metaContent(html, 'og:title') ??
        _extractTitle(html) ??
        _titleFromUrl(url);
    final description = _extractJsonLdDescription(html) ??
        _metaContent(html, 'og:description') ??
        _metaContent(html, 'description') ??
        _metaContent(html, 'twitter:description');
    final body = _extractJsonLdArticleBody(html) ??
        _extractArticleBody(html) ??
        _stripHtml(html);
    final narrative = _composeNarrative(title, description, body);
    return NarrativeLinkContent(
      url: url,
      title: _clamp(title, 240),
      narrative: _clamp(narrative, 4800),
    );
  }

  static int meaningfulLength(String text) {
    var count = 0;
    for (final code in text.runes) {
      final ch = String.fromCharCode(code);
      if (RegExp(r'[A-Za-z0-9]').hasMatch(ch)) count++;
    }
    return count;
  }

  static String _composeNarrative(String title, String? description, String body) {
    final parts = <String>[];
    if (title.isNotEmpty) parts.add(title);
    if (description != null && description.trim().isNotEmpty) {
      parts.add(description.trim());
    }
    if (body.isNotEmpty) {
      parts.add(body);
    }
    return parts.join('\n\n').trim();
  }

  static String? _extractJsonLdArticleBody(String html) =>
      _walkJsonLd(html, (node) {
        final type = _jsonLdType(node);
        if (!_isArticleType(type)) return null;
        final body = node['articleBody'] ?? node['text'];
        if (body is String && body.trim().isNotEmpty) return _stripHtml(body);
        return null;
      });

  static String? _extractJsonLdDescription(String html) =>
      _walkJsonLd(html, (node) {
        final type = _jsonLdType(node);
        if (!_isArticleType(type)) return null;
        final d = node['description'];
        return d is String && d.trim().isNotEmpty ? _decodeEntities(d.trim()) : null;
      });

  static String? _extractJsonLdHeadline(String html) =>
      _walkJsonLd(html, (node) {
        final type = _jsonLdType(node);
        if (!_isArticleType(type)) return null;
        final h = node['headline'] ?? node['name'];
        return h is String && h.trim().isNotEmpty ? _decodeEntities(h.trim()) : null;
      });

  static String? _walkJsonLd(String html, String? Function(Map<String, dynamic>) pick) {
    final pattern = RegExp(
      '<script[^>]+type=["\']application/ld\\+json["\'][^>]*>([\\s\\S]*?)</script>',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final found = _walkJsonLdNode(decoded, pick);
        if (found != null && found.trim().isNotEmpty) return found.trim();
      } catch (_) {}
    }
    return null;
  }

  static String? _walkJsonLdNode(dynamic node, String? Function(Map<String, dynamic>) pick) {
    if (node is List) {
      for (final item in node) {
        final found = _walkJsonLdNode(item, pick);
        if (found != null) return found;
      }
      return null;
    }
    if (node is! Map) return null;
    final map = Map<String, dynamic>.from(node);
    final direct = pick(map);
    if (direct != null) return direct;
    final graph = map['@graph'];
    if (graph != null) return _walkJsonLdNode(graph, pick);
    return null;
  }

  static String? _jsonLdType(Map<String, dynamic> node) {
    final type = node['@type'];
    if (type is String) return type;
    if (type is List && type.isNotEmpty) return '${type.first}';
    return null;
  }

  static bool _isArticleType(String? type) {
    if (type == null) return false;
    final t = type.toLowerCase();
    return t.contains('article') || t.contains('news') || t.contains('blogposting');
  }

  static String? _extractArticleBody(String html) {
    final article = RegExp(
      r'<article[^>]*>([\s\S]*?)</article>',
      caseSensitive: false,
    ).firstMatch(html);
    if (article != null) {
      final text = _stripHtml(article.group(1) ?? '');
      if (text.length >= 40) return text;
    }
    final main = RegExp(
      r'<main[^>]*>([\s\S]*?)</main>',
      caseSensitive: false,
    ).firstMatch(html);
    if (main != null) {
      final text = _stripHtml(main.group(1) ?? '');
      if (text.length >= 40) return text;
    }
    return null;
  }

  static String? _extractTitle(String html) {
    final m = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false).firstMatch(html);
    if (m == null) return null;
    return _decodeEntities(_stripTags(m.group(1) ?? '').trim());
  }

  static String? _metaContent(String html, String key) {
    final patterns = [
      RegExp(
        '<meta[^>]+(?:property|name)=["\']$key["\'][^>]+content=["\']([^"\']*)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']*)["\'][^>]+(?:property|name)=["\']$key["\']',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        final v = _decodeEntities(m.group(1)?.trim() ?? '');
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  static String _stripHtml(String html) {
    var s = html;
    s = s.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'<noscript[\s\S]*?</noscript>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'<header[\s\S]*?</header>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'<footer[\s\S]*?</footer>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'<nav[\s\S]*?</nav>', caseSensitive: false), ' ');
    s = _stripTags(s);
    s = _decodeEntities(s);
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');
    return s.trim();
  }

  static String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _decodeEntities(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');

  static String _titleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.pathSegments.where((s) => s.isNotEmpty).join(' / ');
    return path.isNotEmpty ? path : uri.host;
  }

  static String _clamp(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }
}

class BlueskyPostRef {
  const BlueskyPostRef({required this.handle, required this.rkey});

  final String handle;
  final String rkey;
}

class NarrativeLinkException implements Exception {
  NarrativeLinkException(this.code, {this.cause});

  final String code;
  final Object? cause;

  @override
  String toString() => 'NarrativeLinkException($code)';
}