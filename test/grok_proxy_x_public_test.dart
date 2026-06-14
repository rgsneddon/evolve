import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_config.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_store.dart';

void main() {
  test('fetchNarrativeLink reads public X post without OAuth token', () async {
    const tweetUrl = 'https://x.com/rgsneddon/status/2066269545849880814';
    final client = MockClient((request) async {
      if (request.url.host == 'publish.twitter.com') {
        return http.Response(
          jsonEncode({
            'author_name': 'Russell',
            'author_url': 'https://twitter.com/rgsneddon',
            'html':
                '<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Parliament is just a revolving door of policies we didn\'t vote for.</p></blockquote>',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final store = GrokProxyStore(
      const GrokProxyConfig(
        port: 8787,
        mock: false,
        xClientId: 'test',
        xClientSecret: 'secret',
      ),
      client: client,
    );

    final result = await store.fetchNarrativeLink(tweetUrl);
    expect(result['narrative'], contains('revolving door'));
    expect(result['narrative'], contains('@rgsneddon'));
  });

  test('fetchNarrativeLink falls back to syndication when oembed fails', () async {
    const tweetUrl = 'https://x.com/rgsneddon/status/2066269545849880814';
    final client = MockClient((request) async {
      if (request.url.host == 'publish.twitter.com') {
        return http.Response('not found', 404);
      }
      if (request.url.host == 'cdn.syndication.twimg.com') {
        return http.Response(
          jsonEncode({
            'text': 'Parliament is just a revolving door of policies we didn\'t vote for.',
            'user': {'screen_name': 'rgsneddon'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final store = GrokProxyStore(
      const GrokProxyConfig(
        port: 8787,
        mock: false,
        xClientId: 'test',
        xClientSecret: 'secret',
      ),
      client: client,
    );

    final result = await store.fetchNarrativeLink(tweetUrl);
    expect(result['narrative'], contains('revolving door'));
    expect(result['narrative'], contains('@rgsneddon'));
  });
}