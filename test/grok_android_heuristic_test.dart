import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/services/grok_auth_client.dart';

void main() {
  test('android heuristic fallback reports proxy-ready', () {
    final provider = EvolveProvider();

    expect(provider.grokUsesHeuristicMode, isFalse);
    expect(provider.activateAndroidHeuristicFallbackForTest(), isTrue);
    expect(provider.grokUsesHeuristicMode, isTrue);
    expect(provider.grokConstrualAvailable, isTrue);
  });

  test('beginGrokConstrue fills fields in android heuristic mode without X sign-in', () async {
    final provider = EvolveProvider();
    provider.activateAndroidHeuristicFallbackForTest();
    provider.grokConstrualEnabled = true;
    provider.updateInput(
      provider.input.copyWith(
        posedQuestion: 'What is the chance of civil unrest in Glasgow near-term?',
      ),
    );

    await provider.beginGrokConstrue();

    expect(provider.input.vortexText, startsWith('ω (vortex):'));
    expect(provider.input.shearText, startsWith('σ (shear):'));
    expect(provider.grokFilledFields.length, 4);
  });

  test('login.mock is treated as embedded mock callback', () {
    final localhostMock = Uri.parse(
      'http://127.0.0.1:8787/auth/callback?code=mock&state=mock',
    );
    final mobileMock = Uri.parse('evolve://auth/callback?code=mock&state=mock');

    expect(GrokAuthClient.isEmbeddedMockCallback(localhostMock), isTrue);
    expect(GrokAuthClient.isEmbeddedMockCallback(mobileMock), isFalse);
  });
}