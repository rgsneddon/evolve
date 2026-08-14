import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Matches perc_chain miner_stats HASH_PRESENCE_MS (hashing window).
const int minerHashPresenceMs = 72000;

/// Recipients of one scenario faucet draw.
///
/// Initiator always. When [minerRunning], every user (registered accounts
/// and miner wallets — miners are users) gets the same unit. Not treasury
/// or seed.
List<String> scenarioMirrorRecipients({
  required String initiator,
  required Iterable<String> users,
  required bool minerRunning,
  Iterable<String> extraMiners = const [],
  String treasuryUsername = PercChainConstants.treasuryUsername,
  String seedUsername = PercChainConstants.seedUsername,
}) {
  final init = initiator.trim();
  if (init.isEmpty) return const [];
  final out = <String>{init};
  if (minerRunning) {
    for (final raw in users) {
      final u = raw.trim();
      if (u.isEmpty) continue;
      if (u == treasuryUsername || u == seedUsername) continue;
      out.add(u);
    }
  }
  for (final raw in extraMiners) {
    final u = raw.trim();
    if (u.isEmpty) continue;
    if (u == treasuryUsername || u == seedUsername) continue;
    out.add(u);
  }
  final list = out.toList()..sort();
  return list;
}

/// Parse mineperc `/api/stats` (or a test fixture) into the miner book.
List<Map<String, Object?>> minerBookFromPoolStats(Object? json) {
  if (json is! Map) return const [];
  final workers = json['workers'];
  if (workers is! List) return const [];
  final out = <Map<String, Object?>>[];
  for (final w in workers) {
    if (w is Map) {
      out.add(Map<String, Object?>.from(w));
    }
  }
  return out;
}

/// Wallet identities from the live perc-mine pool book.
/// Worker logins (`rig.raskul`) are ignored; only `wallet` or `percpriv…`
/// usernames are payout identities.
List<String> minerIdentitiesFromBook(Iterable<Map<String, Object?>> book) {
  final out = <String>{};
  for (final m in book) {
    final wallet = '${m['wallet'] ?? ''}'.trim();
    if (wallet.isNotEmpty) {
      out.add(wallet);
      continue;
    }
    final user = '${m['username'] ?? m['login'] ?? ''}'.trim();
    if (user.isEmpty) continue;
    final i = user.indexOf('.');
    final id = i > 0 ? user.substring(0, i) : user;
    if (id.startsWith('percpriv')) out.add(id);
  }
  return out.toList();
}

/// Treasury debit for one draw: unit reward × recipient count.
PercAmount scenarioMirrorTreasuryDebit(PercAmount unit, int recipientCount) {
  final n = recipientCount < 0 ? 0 : recipientCount;
  return unit * n;
}

/// Live perc-mine / pool book: a miner is running if connected or hashed
/// within [minerHashPresenceMs].
bool minerBookHasRunningMiner(
  Iterable<Map<String, Object?>> book, {
  DateTime? now,
}) {
  final t = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
  for (final m in book) {
    if (m['connected'] == true) return true;
    final last = m['lastHashAt'];
    if (last is num && t - last.toInt() <= minerHashPresenceMs) {
      return true;
    }
  }
  return false;
}
