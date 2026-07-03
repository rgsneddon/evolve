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
    required this.opensAt,
    required this.closesAt,
  });

  final String id;
  final String title;
  final String summary;
  final String wardName;
  final DateTime opensAt;
  final DateTime closesAt;

  bool isOpenAt(DateTime now) =>
      !now.isBefore(opensAt) && now.isBefore(closesAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'wardName': wardName,
        'opensAt': opensAt.toIso8601String(),
        'closesAt': closesAt.toIso8601String(),
      };

  factory WardProposal.fromJson(Map<String, dynamic> json) => WardProposal(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        wardName: json['wardName'] as String,
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