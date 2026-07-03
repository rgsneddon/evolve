import '../../models/analysis_mode.dart';

/// Payload passed from an Evolve analysis conclusion into Community Ward Voting.
class WardConclusionLink {
  const WardConclusionLink({
    required this.title,
    required this.summary,
    required this.wardName,
    required this.voteCommentPrefill,
    required this.analysisMode,
    required this.outcomeScore,
    required this.conclusionExcerpt,
    required this.grokEnriched,
    this.posedQuestion = '',
    this.topic = '',
  });

  final String title;
  final String summary;
  final String wardName;
  final String voteCommentPrefill;
  final AnalysisMode analysisMode;
  final double outcomeScore;
  final String conclusionExcerpt;
  final bool grokEnriched;
  final String posedQuestion;
  final String topic;

  /// Normalized title for matching open ward proposals.
  String get matchKey => WardConclusionLink.normalizeTitle(title);

  static String normalizeTitle(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'wardName': wardName,
        'voteCommentPrefill': voteCommentPrefill,
        'analysisMode': analysisMode.wireName,
        'outcomeScore': outcomeScore,
        'conclusionExcerpt': conclusionExcerpt,
        'grokEnriched': grokEnriched,
        'posedQuestion': posedQuestion,
        'topic': topic,
      };

  factory WardConclusionLink.fromJson(Map<String, dynamic> json) =>
      WardConclusionLink(
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        wardName: json['wardName'] as String? ?? '',
        voteCommentPrefill: json['voteCommentPrefill'] as String? ?? '',
        analysisMode: AnalysisModeWire.fromWire(
          json['analysisMode'] as String? ?? '',
        ),
        outcomeScore: (json['outcomeScore'] as num?)?.toDouble() ?? 0,
        conclusionExcerpt: json['conclusionExcerpt'] as String? ?? '',
        grokEnriched: json['grokEnriched'] as bool? ?? false,
        posedQuestion: json['posedQuestion'] as String? ?? '',
        topic: json['topic'] as String? ?? '',
      );
}