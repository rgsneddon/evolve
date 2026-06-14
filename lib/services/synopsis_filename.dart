import '../models/scenario_input.dart';

/// Suggested download basename for synopsis exports.
String synopsisBasename(ScenarioInput input, DateTime stamp) {
  final topic = input.topic.trim();
  final question = input.posedQuestionLine ?? input.vortexText.trim();
  final raw = topic.isNotEmpty ? topic : question;
  final slug = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final clipped = slug.isEmpty
      ? 'report'
      : (slug.length > 40 ? slug.substring(0, 40) : slug);
  final date =
      '${stamp.year}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}';
  return 'evolve-synopsis-$clipped-$date';
}