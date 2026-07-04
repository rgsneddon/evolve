import '../models/scenario_input.dart';
import 'question_semantics.dart';

class EventClassification {
  const EventClassification({
    required this.eventClass,
    required this.horizonDays,
    required this.displayEvent,
  });

  final String eventClass;
  final int horizonDays;
  final String displayEvent;
}

/// Maps posed questions to registry event classes and forecast horizons.
class EventClassifier {
  const EventClassifier();

  EventClassification classify(ScenarioInput input, {String regionId = 'global'}) {
    final sem = QuestionSemantics.parse(input, regionId: regionId);
    final lower = sem.raw.toLowerCase();
    final eventClass = _eventClass(lower);
    final horizonDays = _horizonDays(lower);
    final displayEvent = sem.displaySubject;

    return EventClassification(
      eventClass: eventClass,
      horizonDays: horizonDays,
      displayEvent: displayEvent,
    );
  }

  String _eventClass(String lower) {
    if (RegExp(
      r'\b(unrest|protests?|riot|disorder|march|violence|strike|protestas|disturbios|violencia)\b',
    ).hasMatch(lower)) {
      return 'civil_unrest';
    }
    if (RegExp(r'\b(recession|gdp|inflation|economic downturn|cost of living)\b')
        .hasMatch(lower)) {
      return 'recession';
    }
    if (RegExp(r'\b(election|vote|referendum|re-election|ballot)\b').hasMatch(lower)) {
      return 'election_upset';
    }
    if (RegExp(r'\b(cohesion|trust|demographic|unity|polarization|social fabric)\b')
        .hasMatch(lower)) {
      return 'cohesion_decline';
    }
    if (RegExp(r'\b(policy|legislation|bill|passage|law|regulation)\b').hasMatch(lower)) {
      return 'policy_passage';
    }
    if (RegExp(
      r'\b(world cup|fifa|champions league|euro|olympics|super bowl|stanley cup|'
      r'premier league title|grand slam)\b',
    ).hasMatch(lower) &&
        RegExp(r'\b(win|champion|victory)\b').hasMatch(lower)) {
      return 'sports_championship';
    }
    return 'general_scenario';
  }

  int _horizonDays(String lower) {
    if (RegExp(
      r'\b(this month|next month|30 days|imminent|immediate|este mes|próximo mes)\b',
    ).hasMatch(lower)) {
      return 30;
    }
    if (RegExp(
      r'\b(this year|within a year|12 months|annual|este año|esta año|en el año)\b',
    ).hasMatch(lower)) {
      return 365;
    }
    if (RegExp(
      r'\b(medium[- ]term|near[- ]term|soon|short[- ]term|this quarter|6 months|half year|180 days|medio plazo|6 meses|corto plazo|próximamente)\b',
    ).hasMatch(lower)) {
      return 180;
    }
    return 180;
  }
}