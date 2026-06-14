import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/grok_session.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/grok_auth_client.dart';
import 'package:evolve/services/grok_construal_service.dart';
import 'package:evolve/services/grok_proxy_launcher.dart';
import 'package:evolve/services/grok_service_config.dart';

void main() {
  test('configured proxy URL enables live grok path', () {
    expect(GrokServiceConfig.usesInBrowserConstrual('http://127.0.0.1:8787'), isFalse);
  });

  test('refreshGrokProxy starts embedded proxy on desktop', () async {
    final provider = EvolveProvider();
    await provider.initialize();
    expect(provider.grokProxyConfigured, isTrue);
    final ready = await provider.refreshGrokProxy();
    expect(ready, isTrue);
    await GrokProxyLauncher.instance.stop();
  });

  test('beginGrokConstrue rejects when premium session missing', () async {
    final provider = EvolveProvider();
    provider.grokConstrualEnabled = true;
    provider.grokSession = const GrokSession();
    provider.updateInput(
      provider.input.copyWith(posedQuestion: 'Will protests escalate?'),
    );

    await provider.beginGrokConstrue();

    expect(provider.input.vortexText, isEmpty);
    expect(provider.statusMessage, isNotNull);
  });

  test('live construal throws without premium session', () async {
    final provider = EvolveProvider(
      grokConstrual: const GrokConstrualService(baseUrl: 'http://127.0.0.1:1'),
    );
    provider.grokConstrualEnabled = true;
    provider.grokSession = const GrokSession(connected: true, premium: false);

    expect(
      () => provider.beginGrokConstrue(),
      returnsNormally,
    );
  });
}