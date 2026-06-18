import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/input_edit_guard.dart';

void main() {
  test('isIncrementalEdit accepts prefix typing and deletions', () {
    expect(InputEditGuard.isIncrementalEdit('hello', 'hello'), isTrue);
    expect(InputEditGuard.isIncrementalEdit('hello', 'hello world'), isTrue);
    expect(InputEditGuard.isIncrementalEdit('hello world', 'hello'), isTrue);
    expect(InputEditGuard.isIncrementalEdit('', 'a'), isTrue);
    expect(
      InputEditGuard.isIncrementalEdit(
        'What is the chance of unrest?',
        'What is the chance of unrest near-term?',
      ),
      isTrue,
    );
  });

  test('isIncrementalEdit rejects unrelated swaps', () {
    expect(InputEditGuard.isIncrementalEdit('hello', 'goodbye'), isFalse);
    expect(InputEditGuard.isIncrementalEdit('austerity paths', 'stimulus paths'), isFalse);
  });

  test('isPosedScenarioReset ignores incremental typing', () {
    expect(
      InputEditGuard.isPosedScenarioReset(
        'What is the chance of unrest?',
        'What is the chance of unrest near-term?',
      ),
      isFalse,
    );
    expect(
      InputEditGuard.isPosedScenarioReset(
        'What is the chance of unrest?',
        'Will the mayor win re-election?',
      ),
      isTrue,
    );
  });

  test('isPathwayStructureChanged ignores incremental pathway label edits', () {
    const before = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to end recession',
      outcomeParts: ['austerity', 'stimulus'],
    );
    const typing = ScenarioInput(
      multiPartOutcomeEnabled: true,
      outcomeContext: 'to end recession',
      outcomeParts: ['austerity path', 'stimulus'],
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

    expect(InputEditGuard.isPathwayStructureChanged(before, typing), isFalse);
    expect(InputEditGuard.isPathwayStructureChanged(before, relabel), isTrue);
    expect(InputEditGuard.isPathwayStructureChanged(before, newOutcome), isTrue);
    expect(InputEditGuard.isPathwayStructureChanged(before, before), isFalse);
  });
}