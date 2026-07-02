import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/grok_auth_client.dart';
import 'package:evolve/services/grok_oauth_flow.dart';
import 'package:evolve/services/grok_oauth_redirect_io.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_config.dart';

void main() {
  const auth = GrokAuthClient(baseUrl: 'http://127.0.0.1:1');

  test('android redirect constant uses evolve scheme', () {
    expect(GrokOAuthRedirect.mobileRedirectUri, 'evolve://auth/callback');
    expect(GrokOAuthRedirect.callbackScheme, 'evolve');
  });

  test('desktop proxy config keeps localhost callback', () {
    final config = GrokProxyConfig(
      port: 8787,
      mock: false,
      xClientId: 'test-client',
    );
    expect(config.redirectUri, 'http://127.0.0.1:8787/auth/callback');
  });

  test('sessionFromCallbackUri reports oauth errors', () async {
    final session = await GrokOAuthFlow.sessionFromCallbackUri(
      Uri.parse('evolve://auth/callback?error=access_denied'),
      auth,
    );
    expect(session.connected, isFalse);
    expect(session.oauthError, 'access_denied');
  });

  test('sessionFromCallbackUri reports missing code', () async {
    final session = await GrokOAuthFlow.sessionFromCallbackUri(
      Uri.parse('evolve://auth/callback?state=abc'),
      auth,
    );
    expect(session.oauthError, 'missing_code');
  });
}