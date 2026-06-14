import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/grok_heuristic_construal.dart';
import 'package:evolve/services/grok_service_config.dart';

void main() {
  test('usesInBrowserConstrual is false when a proxy URL is configured', () {
    expect(GrokServiceConfig.usesInBrowserConstrual('http://127.0.0.1:8787'), isFalse);
    expect(GrokServiceConfig.usesInBrowserConstrual('https://proxy.example.com'), isFalse);
  });

  test('heuristic construal fills blank construct fields from posed question', () {
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of civil unrest in Glasgow near-term?',
    );
    final result = GrokHeuristicConstrual.suggest(
      input: input,
      locale: LocaleConfig.defaults,
    );

    expect(result.vortexText, isNotEmpty);
    expect(result.shearText, isNotEmpty);
    expect(result.resistanceText, isNotEmpty);
    expect(result.flowText, isNotEmpty);
    expect(result.provenance, 'grok-heuristic-web');
  });
}