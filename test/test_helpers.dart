import 'package:evolve/models/scenario_input.dart';

/// Minimal complete construct set for offline calculate tests.
ScenarioInput scenarioWithConstructs({
  String posedQuestion = 'What is the chance of civil unrest near-term?',
  String topic = '',
  String sourceUrl = '',
  String vortexText = 'Elite framing compresses protest into disorder risk.',
  String? shearText,
  String? resistanceText,
  String? flowText,
}) =>
    ScenarioInput(
      posedQuestion: posedQuestion,
      topic: topic,
      sourceUrl: sourceUrl,
      vortexText: vortexText,
      shearText: shearText ?? 'Polarized media amplifies grievance layers.',
      resistanceText: resistanceText ?? 'Institutional scepticism meets official framing.',
      flowText: flowText ?? 'Trust transport strains when nuance is compressed.',
    );