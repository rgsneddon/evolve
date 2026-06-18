import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/pathway_construct_texts.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/input_edit_guard.dart';
import 'package:evolve/services/pathway_construal_service.dart';

void main() {
  test('applyPerPathwayResults merges labelled construct lines', () {
    const source = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeParts: ['austerity', 'stimulus'],
    );

    final applied = PathwayConstrualService.applyPerPathwayResults(
      source: source,
      pathwayConstruals: {
        'austerity': const PathwayConstructTexts(
          vortexText: 'ω (vortex): Treasury briefings favour fiscal tightening.',
          shearText: 'σ (shear): Street discourse backs spending cuts.',
        ),
        'stimulus': const PathwayConstructTexts(
          vortexText: 'ω (vortex): Cabinet signals investment-led exit.',
          shearText: 'σ (shear): Labour forums push stimulus narrative.',
        ),
      },
      labelsInOrder: ['austerity', 'stimulus'],
    );

    expect(applied.vortexText, contains('austerity'));
    expect(applied.vortexText, contains('stimulus'));
    expect(applied.shearText, contains('spending cuts'));
    expect(applied.shearText, contains('stimulus narrative'));
    expect(applied.pathwayConstruals.length, 2);
  });

  test('pathwaysChanged detects label and outcome edits', () {
    const before = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to end recession',
      outcomeParts: ['austerity', 'stimulus'],
    );
    const relabel = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to end recession',
      outcomeParts: ['austerity', 'status quo'],
    );
    const newOutcome = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to avoid recession',
      outcomeParts: ['austerity', 'stimulus'],
    );

    expect(InputEditGuard.isPathwayStructureChanged(before, relabel), isTrue);
    expect(InputEditGuard.isPathwayStructureChanged(before, newOutcome), isTrue);
    expect(InputEditGuard.isPathwayStructureChanged(before, before), isFalse);
  });
}