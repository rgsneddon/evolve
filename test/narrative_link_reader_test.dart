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

  test('x.com links are rejected as blocked', () async {
    const reader = NarrativeLinkReader();
    expect(
      () => reader.fetch('https://x.com/example/status/1'),
      throwsA(
        predicate(
          (e) => e is NarrativeLinkException && e.code == 'blocked',
        ),
      ),
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