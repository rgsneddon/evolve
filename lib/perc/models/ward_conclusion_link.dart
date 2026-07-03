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
    this.dualAnalysis = false,
    this.percentChance,
    this.percentPhrase = '',
    this.refinedScs,
    this.scsLean = '',
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
  final bool dualAnalysis;
  final double? percentChance;
  final String percentPhrase;
  final double? refinedScs;
  final String scsLean;

  /// Normalized title for matching open ward proposals.
  String get matchKey => WardConclusionLink.normalizeTitle(title);

  static String normalizeTitle(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  WardConclusionLink copyWith({
    String? title,
    String? summary,
    String? wardName,
    String? voteCommentPrefill,
    AnalysisMode? analysisMode,
    double? outcomeScore,
    String? conclusionExcerpt,
    bool? grokEnriched,
    String? posedQuestion,
    String? topic,
    bool? dualAnalysis,
    double? percentChance,
    String? percentPhrase,
    double? refinedScs,
    String? scsLean,
  }) =>
      WardConclusionLink(
        title: title ?? this.title,
        summary: summary ?? this.summary,
        wardName: wardName ?? this.wardName,
        voteCommentPrefill: voteCommentPrefill ?? this.voteCommentPrefill,
        analysisMode: analysisMode ?? this.analysisMode,
        outcomeScore: outcomeScore ?? this.outcomeScore,
        conclusionExcerpt: conclusionExcerpt ?? this.conclusionExcerpt,
        grokEnriched: grokEnriched ?? this.grokEnriched,
        posedQuestion: posedQuestion ?? this.posedQuestion,
        topic: topic ?? this.topic,
        dualAnalysis: dualAnalysis ?? this.dualAnalysis,
        percentChance: percentChance ?? this.percentChance,
        percentPhrase: percentPhrase ?? this.percentPhrase,
        refinedScs: refinedScs ?? this.refinedScs,
        scsLean: scsLean ?? this.scsLean,
      );

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
        'dualAnalysis': dualAnalysis,
        'percentChance': percentChance,
        'percentPhrase': percentPhrase,
        'refinedScs': refinedScs,
        'scsLean': scsLean,
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
        dualAnalysis: json['dualAnalysis'] as bool? ?? false,
        percentChance: (json['percentChance'] as num?)?.toDouble(),
        percentPhrase: json['percentPhrase'] as String? ?? '',
        refinedScs: (json['refinedScs'] as num?)?.toDouble(),
        scsLean: json['scsLean'] as String? ?? '',
      );
}