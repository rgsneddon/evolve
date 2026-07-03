/// Full-mesh wallet peer links — every wallet connected to every other.
class PercWalletMesh {
  const PercWalletMesh._();

  static Map<String, List<String>> fullMesh(Iterable<String> usernames) {
    final sorted = usernames.toList()..sort();
    final mesh = <String, List<String>>{};
    for (final user in sorted) {
      mesh[user] = sorted.where((other) => other != user).toList();
    }
    return mesh;
  }

  static bool isComplete(
    Map<String, List<String>> mesh,
    Iterable<String> usernames,
  ) {
    final expected = fullMesh(usernames);
    if (mesh.length != expected.length) return false;
    for (final entry in expected.entries) {
      final peers = mesh[entry.key];
      if (peers == null || !_listsEqual(peers, entry.value)) return false;
    }
    return true;
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}