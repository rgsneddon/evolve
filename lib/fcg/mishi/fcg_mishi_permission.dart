/// Voter permission to access the Evolve FCG Voting tab for a forum month.
enum FcgMishiPermissionStatus {
  pending,
  approved,
  rejected,
}

extension FcgMishiPermissionStatusJson on FcgMishiPermissionStatus {
  String toJson() => name;

  static FcgMishiPermissionStatus fromJson(String? raw) =>
      FcgMishiPermissionStatus.values.asNameMap()[raw] ??
          FcgMishiPermissionStatus.pending;
}

class FcgMishiVoterPermission {
  const FcgMishiVoterPermission({
    required this.percAddress,
    required this.walletUsername,
    required this.moderatorUsername,
    required this.wardLabel,
    required this.forumMonth,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedByModerator,
  });

  final String percAddress;
  final String walletUsername;
  final String moderatorUsername;
  final String wardLabel;
  final String forumMonth;
  final FcgMishiPermissionStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? decidedByModerator;

  bool get isApproved => status == FcgMishiPermissionStatus.approved;

  FcgMishiVoterPermission copyWith({
    FcgMishiPermissionStatus? status,
    DateTime? decidedAt,
    String? decidedByModerator,
  }) =>
      FcgMishiVoterPermission(
        percAddress: percAddress,
        walletUsername: walletUsername,
        moderatorUsername: moderatorUsername,
        wardLabel: wardLabel,
        forumMonth: forumMonth,
        status: status ?? this.status,
        requestedAt: requestedAt,
        decidedAt: decidedAt ?? this.decidedAt,
        decidedByModerator: decidedByModerator ?? this.decidedByModerator,
      );

  Map<String, dynamic> toJson() => {
        'percAddress': percAddress,
        'walletUsername': walletUsername,
        'moderatorUsername': moderatorUsername,
        'wardLabel': wardLabel,
        'forumMonth': forumMonth,
        'status': status.toJson(),
        'requestedAt': requestedAt.toUtc().toIso8601String(),
        if (decidedAt != null) 'decidedAt': decidedAt!.toUtc().toIso8601String(),
        if (decidedByModerator != null) 'decidedByModerator': decidedByModerator,
      };

  factory FcgMishiVoterPermission.fromJson(Map<String, dynamic> json) =>
      FcgMishiVoterPermission(
        percAddress: json['percAddress'] as String? ?? '',
        walletUsername: json['walletUsername'] as String? ?? '',
        moderatorUsername: json['moderatorUsername'] as String? ?? '',
        wardLabel: json['wardLabel'] as String? ?? '',
        forumMonth: json['forumMonth'] as String? ?? '',
        status: FcgMishiPermissionStatusJson.fromJson(json['status'] as String?),
        requestedAt: DateTime.parse(
          json['requestedAt'] as String? ?? DateTime.utc(2026).toIso8601String(),
        ).toUtc(),
        decidedAt: json['decidedAt'] == null
            ? null
            : DateTime.parse(json['decidedAt'] as String).toUtc(),
        decidedByModerator: json['decidedByModerator'] as String?,
      );
}

/// Salt + hash only — never stores plaintext moderator passwords.
class FcgMishiModeratorVerifier {
  const FcgMishiModeratorVerifier({
    required this.username,
    required this.salt,
    required this.passwordHash,
    required this.updatedAt,
  });

  final String username;
  final String salt;
  final String passwordHash;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'username': username,
        'salt': salt,
        'passwordHash': passwordHash,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory FcgMishiModeratorVerifier.fromJson(Map<String, dynamic> json) =>
      FcgMishiModeratorVerifier(
        username: json['username'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        passwordHash: json['passwordHash'] as String? ?? '',
        updatedAt: DateTime.parse(
          json['updatedAt'] as String? ?? DateTime.utc(2026).toIso8601String(),
        ).toUtc(),
      );
}

/// Current forum month key (UTC `yyyy-MM`).
String fcgMishiForumMonth([DateTime? now]) {
  final t = (now ?? DateTime.now()).toUtc();
  final m = t.month.toString().padLeft(2, '0');
  return '${t.year}-$m';
}