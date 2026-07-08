/// Moderator actions queued from Mishi for Evolve to apply on the Voting tab.
enum FcgMishiDirectiveKind {
  openVote,
  closeVote,
  amendVote,
  startDebate,
  concludeDebate,
}

extension FcgMishiDirectiveKindJson on FcgMishiDirectiveKind {
  String toJson() => name;

  static FcgMishiDirectiveKind fromJson(String? raw) =>
      FcgMishiDirectiveKind.values.asNameMap()[raw] ??
          FcgMishiDirectiveKind.openVote;
}

class FcgMishiSessionDirective {
  const FcgMishiSessionDirective({
    required this.id,
    required this.kind,
    required this.moderatorUsername,
    required this.regionId,
    required this.queuedAt,
    this.policyQuestion = '',
    this.runCohesion = true,
    this.runPercent = true,
  });

  final String id;
  final FcgMishiDirectiveKind kind;
  final String moderatorUsername;
  final String regionId;
  final DateTime queuedAt;
  final String policyQuestion;
  final bool runCohesion;
  final bool runPercent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.toJson(),
        'moderatorUsername': moderatorUsername,
        'regionId': regionId,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'policyQuestion': policyQuestion,
        'runCohesion': runCohesion,
        'runPercent': runPercent,
      };

  factory FcgMishiSessionDirective.fromJson(Map<String, dynamic> json) =>
      FcgMishiSessionDirective(
        id: json['id'] as String? ?? '',
        kind: FcgMishiDirectiveKindJson.fromJson(json['kind'] as String?),
        moderatorUsername: json['moderatorUsername'] as String? ?? '',
        regionId: json['regionId'] as String? ?? 'uk_ireland',
        queuedAt: DateTime.parse(
          json['queuedAt'] as String? ?? DateTime.utc(2026).toIso8601String(),
        ).toUtc(),
        policyQuestion: json['policyQuestion'] as String? ?? '',
        runCohesion: json['runCohesion'] as bool? ?? true,
        runPercent: json['runPercent'] as bool? ?? true,
      );
}