import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:evolve/services/narrative_link_reader.dart';

void main() {
  test('normalizeUrl accepts bare domains', () {
    final uri = NarrativeLinkReader.normalizeUrl('example.com/article');
    expect(uri?.scheme, 'https');
    expect(uri?.host, 'example.com');
  });

  test('normalizeUrl upgrades implicit scheme to https', () {
    final uri = NarrativeLinkReader.normalizeUrl('http://news.test/story');
    expect(uri?.scheme, 'http');
    expect(
      NarrativeLinkReader.normalizeUrl('news.test/story')?.scheme,
      'https',
    );
  });

  test('parseHtml extracts title description and body', () {
    const html = '''
    <html><head>
    <title>Minister Statement on Protests</title>
    <meta property="og:description" content="Polarized pushback across cities." />
    </head><body>
    <p>First Minister condemned disorder while praising peaceful marches.</p>
    </body></html>
    ''';

    final content = NarrativeLinkReader.parseHtml(html, 'https://news.test/story');
    expect(content.title, 'Minister Statement on Protests');
    expect(content.narrative, contains('Polarized pushback'));
    expect(content.narrative, contains('peaceful marches'));
    expect(content.url, 'https://news.test/story');
  });

  test('parseHtml prefers JSON-LD articleBody', () {
    const html = '''
    <html><head><title>Ignored</title></head><body>
    <script type="application/ld+json">
    {"@type":"NewsArticle","headline":"Registry Protest Coverage",
     "description":"Tensions in Glasgow.",
     "articleBody":"<p>Council leaders met community groups after overnight disorder spread to three wards with verified arrests.</p>"}
    </script>
    <p>Shell only.</p>
    </body></html>
    ''';

    final content = NarrativeLinkReader.parseHtml(html, 'https://news.test/ld');
    expect(content.title, 'Registry Protest Coverage');
    expect(content.narrative, contains('Council leaders met community groups'));
    expect(content.narrative, contains('Tensions in Glasgow'));
  });

  test('parseHtml prefers article element body', () {
    const html = '''
    <html><body>
    <nav>Menu</nav>
    <article><p>Mayor issued a differentiated enforcement statement after liaison forums convened across affected wards.</p></article>
    <footer>Copyright</footer>
    </body></html>
    ''';

    final content = NarrativeLinkReader.parseHtml(html, 'https://news.test/article');
    expect(content.narrative, contains('differentiated enforcement statement'));
    expect(content.narrative, isNot(contains('Copyright')));
  });

  test('invalid url throws on fetch', () async {
    const reader = NarrativeLinkReader();
    expect(
      () => reader.fetch('not a url'),
      throwsA(isA<NarrativeLinkException>()),
    );
  });

  test('social media links are rejected as blocked without proxy', () async {
    const reader = NarrativeLinkReader();
    for (final url in [
      'https://x.com/example/status/1',
      'https://instagram.com/p/abc123',
      'https://www.facebook.com/post/1',
      'https://www.tiktok.com/@user/video/1',
      'https://bsky.app/profile/alice/post/3kx',
    ]) {
      expect(
        () => reader.fetch(url),
        throwsA(
          predicate(
            (e) => e is NarrativeLinkException && e.code == 'blocked',
          ),
        ),
        reason: url,
      );
    }
  });

  test('requiresProxyFetch covers major social hosts', () {
    expect(
      NarrativeLinkReader.isSocialMediaUrl('https://x.com/a/status/1'),
      isTrue,
    );
    expect(
      NarrativeLinkReader.isSocialMediaUrl('https://youtu.be/abc123'),
      isTrue,
    );
    expect(
      NarrativeLinkReader.isSocialMediaUrl('https://news.test/story'),
      isFalse,
    );
    final mastodon = Uri.parse('https://mastodon.social/@alice/123456');
    expect(NarrativeLinkReader.requiresProxyFetch(mastodon), isTrue);
  });

  test('minMeaningfulCharsForUri is lower for short-form posts', () {
    expect(
      NarrativeLinkReader.minMeaningfulCharsForUri(
        Uri.parse('https://x.com/a/status/1'),
      ),
      NarrativeLinkReader.minMeaningfulCharsShortForm,
    );
    expect(
      NarrativeLinkReader.minMeaningfulCharsForUri(
        Uri.parse('https://news.test/article'),
      ),
      NarrativeLinkReader.minMeaningfulChars,
    );
  });

  test('parseOembedTweetHtml extracts tweet body', () {
    const html =
        '<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Parliament is just a revolving door of policies we didn\'t vote for.</p>&mdash; Russell (@example_user) <a href="https://twitter.com/example_user/status/1">June 14, 2026</a></blockquote>';
    expect(
      NarrativeLinkReader.parseOembedTweetHtml(html),
      'Parliament is just a revolving door of policies we didn\'t vote for.',
    );
    expect(
      NarrativeLinkReader.authorHandleFromOembed({
        'author_url': 'https://twitter.com/example_user',
      }),
      'example_user',
    );
  });

  test('platform URL helpers parse common shapes', () {
    expect(
      NarrativeLinkReader.youtubeIdFromUri(
        Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      ),
      'dQw4w9WgXcQ',
    );
    expect(
      NarrativeLinkReader.blueskyPostFromUri(
        Uri.parse('https://bsky.app/profile/alice.bsky.social/post/3kxabc'),
      ),
      isNotNull,
    );
    expect(
      NarrativeLinkReader.redditJsonPath(
        Uri.parse('https://www.reddit.com/r/news/comments/abc/title'),
      ),
      '/r/news/comments/abc/title.json',
    );
  });

  test('fetch throws empty when page has no readable narrative', () async {
    final client = MockClient((request) async {
      return http.Response(
        '<html><head><title>Login</title></head><body><p>Sign in</p></body></html>',
        200,
      );
    });
    final reader = NarrativeLinkReader(client: client);
    expect(
      () => reader.fetch('https://news.test/paywall'),
      throwsA(
        predicate(
          (e) => e is NarrativeLinkException && e.code == 'empty',
        ),
      ),
    );
  });

  test('fetch succeeds with browser-like client on https article', () async {
    final client = MockClient((request) async {
      expect(request.headers['User-Agent'], isNotEmpty);
      expect(request.url.scheme, 'https');
      return http.Response(
        '''
        <html><head>
        <title>City unrest briefing</title>
        <meta property="og:description" content="Officials review ward-level incident timelines." />
        </head><body>
        <article><p>Police published verified arrest data while community liaison officers met organisers within fourteen days of the first disorder reports.</p></article>
        </body></html>
        ''',
        200,
      );
    });
    final reader = NarrativeLinkReader(client: client);
    final content = await reader.fetch('https://news.test/briefing');
    expect(content.title, 'City unrest briefing');
    expect(content.narrative, contains('verified arrest data'));
  });
}