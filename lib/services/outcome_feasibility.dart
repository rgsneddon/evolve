import '../models/scenario_input.dart';

/// Whether a posed outcome is still achievable or already foreclosed.
class OutcomeFeasibility {
  const OutcomeFeasibility({
    required this.isForeclosed,
    this.reason,
  });

  const OutcomeFeasibility.open() : isForeclosed = false, reason = null;

  final bool isForeclosed;
  final String? reason;

  static const double foreclosedPercent = 1.0;
  static const int foreclosedCiLow = 0;
  static const int foreclosedCiHigh = 2;
}

/// Detects outcomes that are already impossible (eliminated, settled, etc.).
class OutcomeFeasibilityChecker {
  const OutcomeFeasibilityChecker();

  static final _winIntent = RegExp(
    r'\b(win(?:s|ning)?|champion(?:ship)?|victory|take the|lift the|claim the|hoist)\b',
  );
  static final _tournament = RegExp(
    r'\b(world cup|fifa|euros?|champions league|premier league|olympics|'
    r'tournament|nba finals|super bowl|stanley cup|grand slam)\b',
  );
  static final _elimination = RegExp(
    r'\b(eliminated|knocked out|out of the|failed to qualify|did not qualify|'
    r'not qualify|already out|no longer in|cannot compete|ruled out|ousted|'
    r'beaten out|not in the)\b',
  );

  OutcomeFeasibility check(ScenarioInput input, {String regionId = 'global'}) {
    final text = _combinedText(input);
    if (text.isEmpty) return const OutcomeFeasibility.open();

    final lower = text.toLowerCase();

    if (!_isSportsWinQuestion(lower)) {
      return const OutcomeFeasibility.open();
    }

    for (final entry in _settledForeclosures) {
      if (entry.matches(lower)) {
        return OutcomeFeasibility(
          isForeclosed: true,
          reason: entry.reason,
        );
      }
    }

    if (_elimination.hasMatch(lower)) {
      return const OutcomeFeasibility(
        isForeclosed: true,
        reason: 'Participant already eliminated from the tournament',
      );
    }

    return const OutcomeFeasibility.open();
  }

  bool _isSportsWinQuestion(String lower) =>
      _winIntent.hasMatch(lower) && _tournament.hasMatch(lower);

  String _combinedText(ScenarioInput input) {
    final parts = <String>[
      input.scenarioQuery,
      input.topic,
      input.vortexText,
      input.shearText,
      input.resistanceText,
      input.flowText,
    ];
    return parts.where((p) => p.trim().isNotEmpty).join(' ');
  }
}

class _SettledForeclosure {
  const _SettledForeclosure({
    required this.entities,
    required this.events,
    required this.reason,
  });

  final List<String> entities;
  final List<String> events;
  final String reason;

  bool matches(String lower) {
    final hasEntity = entities.any(lower.contains);
    final hasEvent = events.any(lower.contains);
    return hasEntity && hasEvent && OutcomeFeasibilityChecker._winIntent.hasMatch(lower);
  }
}

/// Known settled outcomes — expand as tournaments conclude.
const _settledForeclosures = <_SettledForeclosure>[
  _SettledForeclosure(
    entities: ['scotland', 'scottish', 'scots'],
    events: ['world cup', 'fifa'],
    reason: 'Scotland eliminated — cannot win the 2026 FIFA World Cup',
  ),
];