/// Moderator grant of Evolve forum-vote access for one (forum month, voting epoch) pair.
enum MishiAccessDecision { pending, approved, denied }

class MishiAccessRequest {
  const MishiAccessRequest({
    required this.username,
    required this.forumMonth,
    required this.votingEpoch,
    this.status = MishiAccessDecision.pending,
  });

  final String username;
  final String forumMonth;
  final String votingEpoch;
  final MishiAccessDecision status;

  String get pairKey => accessPairKey(forumMonth, votingEpoch);

  bool get isApproved => status == MishiAccessDecision.approved;

  MishiAccessRequest copyWith({MishiAccessDecision? status}) =>
      MishiAccessRequest(
        username: username,
        forumMonth: forumMonth,
        votingEpoch: votingEpoch,
        status: status ?? this.status,
      );
}

/// Stable key for a monthly forum vote + voting epoch pair.
String accessPairKey(String forumMonth, String votingEpoch) {
  final month = forumMonth.trim();
  final epoch = votingEpoch.trim();
  return '$month|$epoch';
}

/// In-memory access book used by the Mishi GUI and by tests.
///
/// Approval is pair-scoped: a grant for (month A, epoch X) does not grant
/// (month A, epoch Y) or (month B, epoch X).
class MishiAccessBook {
  MishiAccessBook();

  final Map<String, MishiAccessRequest> _byIdentity = {};

  static String identityKey({
    required String username,
    required String forumMonth,
    required String votingEpoch,
  }) {
    return '${username.trim().toLowerCase()}|${accessPairKey(forumMonth, votingEpoch)}';
  }

  MishiAccessRequest requestAccess({
    required String username,
    required String forumMonth,
    required String votingEpoch,
  }) {
    final key = identityKey(
      username: username,
      forumMonth: forumMonth,
      votingEpoch: votingEpoch,
    );
    final existing = _byIdentity[key];
    if (existing != null) return existing;
    final created = MishiAccessRequest(
      username: username.trim().toLowerCase(),
      forumMonth: forumMonth.trim(),
      votingEpoch: votingEpoch.trim(),
    );
    _byIdentity[key] = created;
    return created;
  }

  MishiAccessRequest approve({
    required String username,
    required String forumMonth,
    required String votingEpoch,
  }) {
    final current = requestAccess(
      username: username,
      forumMonth: forumMonth,
      votingEpoch: votingEpoch,
    );
    final approved = current.copyWith(status: MishiAccessDecision.approved);
    _byIdentity[identityKey(
      username: username,
      forumMonth: forumMonth,
      votingEpoch: votingEpoch,
    )] = approved;
    return approved;
  }

  MishiAccessRequest deny({
    required String username,
    required String forumMonth,
    required String votingEpoch,
  }) {
    final current = requestAccess(
      username: username,
      forumMonth: forumMonth,
      votingEpoch: votingEpoch,
    );
    final denied = current.copyWith(status: MishiAccessDecision.denied);
    _byIdentity[identityKey(
      username: username,
      forumMonth: forumMonth,
      votingEpoch: votingEpoch,
    )] = denied;
    return denied;
  }

  bool hasAccess({
    required String username,
    required String forumMonth,
    required String votingEpoch,
  }) {
    final row = _byIdentity[identityKey(
      username: username,
      forumMonth: forumMonth,
      votingEpoch: votingEpoch,
    )];
    return row?.isApproved ?? false;
  }

  List<MishiAccessRequest> get all =>
      List<MishiAccessRequest>.unmodifiable(_byIdentity.values);
}
