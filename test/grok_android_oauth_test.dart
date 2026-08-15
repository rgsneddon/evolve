import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/grok_session.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/grok_auth_client.dart';
import 'package:evolve/services/grok_oauth_flow.dart';
import 'package:evolve/services/grok_oauth_redirect.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_config.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_store.dart';
import 'package:evolve/services/grok_proxy_launcher.dart';

void main() {
  setUp(() {
    GrokOAuthFlow.completeAuthorizationOverride = null;
  });

  tearDown(() async {
    GrokOAuthFlow.completeAuthorizationOverride = null;
    debugDefaultTargetPlatformOverride = null;
    await GrokProxyLauncher.instance.stop();
    EvolveProvider.skipEmbeddedGrokProxyForTests = true;
    GrokProxyLauncher.disableEmbeddedProxyForTests = false;
  });

  void useAndroidTarget() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }

  test('Android redirect is the evolve custom-scheme callback', () {
    useAndroidTarget();
    expect(GrokOAuthRedirect.usesMobileRedirect, isTrue);
    expect(GrokOAuthRedirect.mobileRedirectUri, 'evolve://auth/callback');
    expect(GrokOAuthRedirect.callbackScheme, 'evolve');
    expect(GrokOAuthFlow.usesMobileDeepLink, isTrue);
  });

  test('canConstrue is true only for a live X Premium session', () {
    expect(const GrokSession().canConstrue, isFalse);
    expect(
      const GrokSession(connected: true, premium: false).canConstrue,
      isFalse,
    );
    expect(
      const GrokSession(connected: true, premium: true, mock: true).canConstrue,
      isFalse,
    );
    expect(
      const GrokSession(connected: true, premium: true, mock: false).canConstrue,
      isTrue,
    );
  });

  test('live Android proxy config authorizes on x.com with evolve callback',
      () async {
    useAndroidTarget();
    final store = GrokProxyStore(
      const GrokProxyConfig(
        port: 8787,
        mock: false,
        xClientId: 'android-client',
      ),
    );
    final url = Uri.parse(await store.authorizeUrl());
    expect(url.host, 'x.com');
    expect(url.path, '/i/oauth2/authorize');
    expect(url.queryParameters['client_id'], 'android-client');
    expect(url.queryParameters['redirect_uri'], 'evolve://auth/callback');
    expect(store.mock, isFalse);
  });

  test('mock proxy authorize URL is not an X page', () async {
    final store = GrokProxyStore(
      const GrokProxyConfig(port: 8787, mock: true),
    );
    final url = Uri.parse(await store.authorizeUrl());
    expect(url.host, isNot('x.com'));
    expect(url.queryParameters['code'], 'mock');
  });

  test('Android does not enter heuristic when embedded proxy is unreachable',
      () async {
    useAndroidTarget();
    EvolveProvider.skipEmbeddedGrokProxyForTests = false;
    GrokProxyLauncher.disableEmbeddedProxyForTests = true;

    final provider = EvolveProvider();
    await provider.initialize();
    final ready = await provider.refreshGrokProxy();

    expect(ready, isFalse);
    expect(provider.grokUsesHeuristicMode, isFalse);
    expect(provider.grokSession.canConstrue, isFalse);

    provider.grokConstrualEnabled = true;
    provider.updateInput(
      provider.input.copyWith(
        posedQuestion: 'What is the chance of unrest in Glasgow near-term?',
      ),
    );
    await provider.beginGrokConstrue();

    expect(provider.input.vortexText, isEmpty);
    expect(provider.input.shearText, isEmpty);
    expect(provider.grokFilledFields, isEmpty);
    expect(provider.statusMessage, isNotNull);
  });

  test('beginGrokConstrue leaves fields empty without Premium', () async {
    final provider = EvolveProvider();
    provider.grokConstrualEnabled = true;
    provider.grokSession = const GrokSession(connected: true, premium: false);
    provider.updateInput(
      provider.input.copyWith(posedQuestion: 'Will protests escalate?'),
    );

    await provider.beginGrokConstrue();

    expect(provider.grokUsesHeuristicMode, isFalse);
    expect(provider.input.vortexText, isEmpty);
    expect(provider.grokFilledFields, isEmpty);
    expect(provider.statusMessage, contains('Premium'));
  });

  test('beginGrokConstrue rejects a mock session', () async {
    final provider = EvolveProvider();
    provider.grokConstrualEnabled = true;
    provider.grokSession = const GrokSession(
      connected: true,
      premium: true,
      mock: true,
      screenName: 'evolve_android',
    );
    provider.updateInput(
      provider.input.copyWith(posedQuestion: 'Will protests escalate?'),
    );

    await provider.beginGrokConstrue();

    expect(provider.grokUsesHeuristicMode, isFalse);
    expect(provider.input.vortexText, isEmpty);
    expect(provider.grokFilledFields, isEmpty);
    expect(provider.statusMessage, contains('Premium'));
  });

  testWidgets('Android Use with mock login does not enter heuristic',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final auth = _ScriptedGrokAuth(
        login: GrokLoginStart(
          authorizeUrl: Uri.parse('evolve://auth/callback?code=mock&state=mock'),
          redirectUri: GrokOAuthRedirect.mobileRedirectUri,
          mock: true,
        ),
      );
      final provider = EvolveProvider(grokAuth: auth);
      await provider.initialize();

      await tester.pumpWidget(_host(provider));
      await tester.tap(find.text('use'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(provider.grokUsesHeuristicMode, isFalse);
      expect(provider.grokSession.canConstrue, isFalse);
      expect(provider.input.vortexText, isEmpty);
      expect(provider.statusMessage, isNotNull);
      expect(provider.statusMessage!.toLowerCase(), contains('x_client_id'));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android Use opens X authorize and requires Premium canConstrue',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final authorize = Uri.parse(
        'https://x.com/i/oauth2/authorize?client_id=android-client'
        '&redirect_uri=evolve%3A%2F%2Fauth%2Fcallback',
      );
      Uri? opened;
      GrokOAuthFlow.completeAuthorizationOverride =
          ({required authorizeUrl, required auth}) async {
        opened = authorizeUrl;
        return const GrokSession(
          connected: true,
          premium: false,
          screenName: 'no_premium',
          mock: false,
        );
      };
      final auth = _ScriptedGrokAuth(
        login: GrokLoginStart(
          authorizeUrl: authorize,
          redirectUri: GrokOAuthRedirect.mobileRedirectUri,
          clientId: 'android-client',
        ),
      );
      final provider = EvolveProvider(grokAuth: auth);
      await provider.initialize();

      await tester.pumpWidget(_host(provider));
      await tester.tap(find.text('use'));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      expect(opened?.host, 'x.com');
      expect(opened?.path, '/i/oauth2/authorize');
      expect(provider.grokUsesHeuristicMode, isFalse);
      expect(provider.grokSession.canConstrue, isFalse);
      expect(provider.input.vortexText, isEmpty);
      expect(provider.statusMessage, contains('Premium'));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android Use with Premium session connects the user account',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final authorize = Uri.parse(
        'https://x.com/i/oauth2/authorize?client_id=android-client',
      );
      GrokOAuthFlow.completeAuthorizationOverride =
          ({required authorizeUrl, required auth}) async {
        expect(authorizeUrl.host, 'x.com');
        return const GrokSession(
          connected: true,
          premium: true,
          screenName: 'alice',
          mock: false,
        );
      };
      final auth = _ScriptedGrokAuth(
        login: GrokLoginStart(
          authorizeUrl: authorize,
          redirectUri: GrokOAuthRedirect.mobileRedirectUri,
          clientId: 'android-client',
        ),
      );
      final provider = EvolveProvider(grokAuth: auth);
      await provider.initialize();

      await tester.pumpWidget(_host(provider));
      await tester.tap(find.text('use'));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      expect(provider.grokSession.canConstrue, isTrue);
      expect(provider.grokSession.screenName, 'alice');
      expect(provider.grokUsesHeuristicMode, isFalse);
      expect(provider.grokConstrualEnabled, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _host(EvolveProvider provider) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => provider.setGrokConstrual(true, context),
          child: const Text('use'),
        ),
      ),
    ),
  );
}

class _ScriptedGrokAuth extends GrokAuthClient {
  _ScriptedGrokAuth({
    this.login,
    this.status = const GrokSession(),
  });

  final GrokLoginStart? login;
  GrokSession status;

  @override
  Future<bool> isProxyReachable() async => true;

  @override
  Future<GrokSession> fetchStatus() async => status;

  @override
  Future<GrokLoginStart> beginLogin() async {
    final started = login;
    if (started == null) {
      throw GrokAuthException('login', message: 'missing scripted login');
    }
    return started;
  }

  @override
  Future<void> logout() async {
    status = const GrokSession();
  }
}
