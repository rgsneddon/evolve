/// Community ward governance — open proposals and cast ballots.
enum WardVoteChoice {
  forProposal,
  against,
  abstain,
}

class WardProposal {
  const WardProposal({
    required this.id,
    required this.title,
    required this.summary,
    required this.wardName,
    required this.proposerUsername,
    required this.opensAt,
    required this.closesAt,
  });

  /// Every user proposal is listed for all wallets for this many days.
  static const int listingDays = 10;

  final String id;
  final String title;
  final String summary;
  final String wardName;
  final String proposerUsername;
  final DateTime opensAt;
  final DateTime closesAt;

  bool isOpenAt(DateTime now) =>
      !now.isBefore(opensAt) && now.isBefore(closesAt);

  Duration listingRemaining(DateTime now) {
    final end = closesAt.toUtc();
    final t = now.toUtc();
    if (!t.isBefore(end)) return Duration.zero;
    return end.difference(t);
  }

  int listingDaysRemaining(DateTime now) {
    final remaining = listingRemaining(now);
    if (remaining <= Duration.zero) return 0;
    return remaining.inDays + (remaining.inHours % 24 > 0 ? 1 : 0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'wardName': wardName,
        'proposerUsername': proposerUsername,
        'opensAt': opensAt.toIso8601String(),
        'closesAt': closesAt.toIso8601String(),
      };

  factory WardProposal.fromJson(Map<String, dynamic> json) => WardProposal(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        wardName: json['wardName'] as String,
        proposerUsername: json['proposerUsername'] as String? ?? 'community',
        opensAt: DateTime.parse(json['opensAt'] as String),
        closesAt: DateTime.parse(json['closesAt'] as String),
      );
}

class WardBallot {
  const WardBallot({
    required this.proposalId,
    required this.voterUsername,
    required this.choice,
    required this.comment,
    required this.castAt,
  });

  final String proposalId;
  final String voterUsername;
  final WardVoteChoice choice;
  final String comment;
  final DateTime castAt;

  Map<String, dynamic> toJson() => {
        'proposalId': proposalId,
        'voterUsername': voterUsername,
        'choice': choice.name,
        'comment': comment,
        'castAt': castAt.toIso8601String(),
      };

  factory WardBallot.fromJson(Map<String, dynamic> json) => WardBallot(
        proposalId: json['proposalId'] as String,
        voterUsername: json['voterUsername'] as String,
        choice: WardVoteChoice.values.firstWhere(
          (c) => c.name == json['choice'],
          orElse: () => WardVoteChoice.abstain,
        ),
        comment: json['comment'] as String? ?? '',
        castAt: DateTime.parse(json['castAt'] as String),
      );
}