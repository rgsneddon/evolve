import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:evolve/services/narrative_link_reader.dart';

void main() {
  test('tweetIdFromUri parses x.com status URLs', () {
    final uri = Uri.parse('https://x.com/example/status/1234567890?s=20');
    expect(NarrativeLinkReader.tweetIdFromUri(uri), '1234567890');
  });

  test('isXUrl detects twitter hosts', () {
    expect(NarrativeLinkReader.isXUrl('https://twitter.com/a/status/1'), isTrue);
    expect(NarrativeLinkReader.isXUrl('https://news.test/story'), isFalse);
  });

  test('fetchViaProxy maps proxy JSON to NarrativeLinkContent', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/narrative/fetch');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['url'], contains('example.com'));
      return http.Response(
        jsonEncode({
          'url': 'https://example.com/post',
          'title': 'Example Post',
          'narrative': 'A' * 120,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final reader = NarrativeLinkReader(client: client);
    final content = await reader.fetchViaProxy(
      'http://127.0.0.1:8787',
      'https://example.com/post',
    );
    expect(content.title, 'Example Post');
    expect(content.narrative.length, greaterThanOrEqualTo(120));
  });

  test('fetchViaProxy surfaces x_auth_required from proxy', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'x_auth_required'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    });

    final reader = NarrativeLinkReader(client: client);
    expect(
      () => reader.fetchViaProxy('http://127.0.0.1:8787', 'https://x.com/a/status/1'),
      throwsA(
        predicate(
          (e) => e is NarrativeLinkException && e.code == 'x_auth_required',
        ),
      ),
    );
  });
}