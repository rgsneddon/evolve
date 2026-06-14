import '../l10n/localized_output.dart';

class OutcomeRecord {
  const OutcomeRecord({
    required this.id,
    required this.eventClass,
    required this.regionId,
    required this.horizonDays,
    required this.yearPosed,
    required this.occurred,
    required this.source,
  });

  final String id;
  final String eventClass;
  final String regionId;
  final int horizonDays;
  final int yearPosed;
  final bool occurred;
  final String source;

  factory OutcomeRecord.fromJson(Map<String, dynamic> json) => OutcomeRecord(
        id: json['id'] as String,
        eventClass: json['eventClass'] as String,
        regionId: json['regionId'] as String,
        horizonDays: json['horizonDays'] as int,
        yearPosed: json['yearPosed'] as int,
        occurred: json['occurred'] as bool,
        source: json['source'] as String,
      );

  /// Exact registry row used in base-rate lookup.
  String caseLabel(LocalizedOutput output) {
    final outcome = occurred
        ? output.strings.t('registry_case_occurred')
        : output.strings.t('registry_case_not_occurred');
    return output.strings
        .t('registry_case_line')
        .replaceAll('{id}', id)
        .replaceAll('{event_class}', output.eventClassLabel(eventClass))
        .replaceAll('{region}', output.regionName(regionId))
        .replaceAll('{horizon}', '$horizonDays')
        .replaceAll('{year}', '$yearPosed')
        .replaceAll('{outcome}', outcome)
        .replaceAll('{source}', source);
  }
}