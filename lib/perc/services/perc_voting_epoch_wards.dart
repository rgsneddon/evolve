/// Voting epochs drive the chain into wards.
class PercWardSlice {
  const PercWardSlice({
    required this.epochId,
    required this.wardIndex,
    required this.wardId,
    required this.label,
  });

  final String epochId;
  final int wardIndex;
  final String wardId;
  final String label;

  Map<String, dynamic> toJson() => {
        'epochId': epochId,
        'wardIndex': wardIndex,
        'wardId': wardId,
        'label': label,
      };
}

/// Maps a voting epoch identifier onto a deterministic ward set.
class PercVotingEpochWards {
  const PercVotingEpochWards._();

  /// Default ward cardinality per monthly voting epoch.
  static const int wardsPerEpoch = 8;

  static List<PercWardSlice> wardsForEpoch(
    String epochId, {
    int? wardCount,
  }) {
    final id = epochId.trim();
    final n = (wardCount ?? wardsPerEpoch).clamp(1, 64);
    if (id.isEmpty) return const [];
    return List<PercWardSlice>.generate(n, (i) {
      final idx = i + 1;
      return PercWardSlice(
        epochId: id,
        wardIndex: idx,
        wardId: 'ward-$id-$idx',
        label: 'Ward $idx · $id',
      );
    });
  }
}
