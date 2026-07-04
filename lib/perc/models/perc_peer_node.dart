/// Network presence for a Perccent wallet — each online wallet acts as a chain node.
class PercPeerNode {
  const PercPeerNode({
    required this.username,
    this.endpoint,
    required this.blockHeight,
    this.tipHash,
    this.online = false,
    required this.lastSeen,
  });

  final String username;
  final String? endpoint;
  final int blockHeight;
  final String? tipHash;
  final bool online;
  final DateTime lastSeen;

  PercPeerNode copyWith({
    String? endpoint,
    int? blockHeight,
    String? tipHash,
    bool? online,
    DateTime? lastSeen,
  }) =>
      PercPeerNode(
        username: username,
        endpoint: endpoint ?? this.endpoint,
        blockHeight: blockHeight ?? this.blockHeight,
        tipHash: tipHash ?? this.tipHash,
        online: online ?? this.online,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  static PercPeerNode offline({
    required String username,
    required int blockHeight,
    String? tipHash,
    DateTime? lastSeen,
  }) =>
      PercPeerNode(
        username: username,
        blockHeight: blockHeight,
        tipHash: tipHash,
        online: false,
        lastSeen: lastSeen ?? DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        if (endpoint != null) 'endpoint': endpoint,
        'blockHeight': blockHeight,
        if (tipHash != null) 'tipHash': tipHash,
        'online': online,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory PercPeerNode.fromJson(Map<String, dynamic> json) => PercPeerNode(
        username: json['username'] as String,
        endpoint: json['endpoint'] as String?,
        blockHeight: json['blockHeight'] as int? ?? 0,
        tipHash: json['tipHash'] as String?,
        online: json['online'] as bool? ?? false,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : DateTime.now().toUtc(),
      );
}