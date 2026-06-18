import '../models/scenario_input.dart';

/// Distinguishes incremental typing from a genuine scenario/pathway swap.
class InputEditGuard {
  const InputEditGuard._();

  /// True when [after] extends or shortens [before] by typing — not a new scenario.
  static bool isIncrementalEdit(String before, String after) {
    final b = before.trim();
    final a = after.trim();
    if (b == a) return true;
    if (b.isEmpty || a.isEmpty) return true;
    if (a.startsWith(b) || b.startsWith(a)) return true;

    // Appending or deleting before a trailing "?" (common in posed questions).
    final bStem = _questionStem(b);
    final aStem = _questionStem(a);
    if (bStem.isNotEmpty &&
        aStem.isNotEmpty &&
        (aStem.startsWith(bStem) || bStem.startsWith(aStem))) {
      return true;
    }
    return false;
  }

  static String _questionStem(String text) {
    final t = text.trim();
    if (t.endsWith('?')) return t.substring(0, t.length - 1).trimRight();
    return t;
  }

  /// Posed question swapped to a different scenario (not mid-typing).
  static bool isPosedScenarioReset(String before, String after) {
    final b = before.trim();
    final a = after.trim();
    if (b == a) return false;
    if (isIncrementalEdit(b, a)) return false;
    return true;
  }

  /// Pathway structure or labels changed beyond incremental typing.
  static bool isPathwayStructureChanged(ScenarioInput before, ScenarioInput after) {
    if (before.multiPartOutcomeEnabled != after.multiPartOutcomeEnabled) return true;

    if (!isIncrementalEdit(before.outcomeContext, after.outcomeContext) &&
        before.outcomeContext.trim() != after.outcomeContext.trim()) {
      return true;
    }

    if (before.outcomeParts.length != after.outcomeParts.length) return true;

    for (var i = 0; i < before.outcomeParts.length; i++) {
      final b = before.outcomeParts[i];
      final a = after.outcomeParts[i];
      if (b == a) continue;
      if (isIncrementalEdit(b, a)) continue;
      return true;
    }
    return false;
  }
}