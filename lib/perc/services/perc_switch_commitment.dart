import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Grin-style switch-commitment layer for hash-based PERC bindings.
///
/// Lets validation tighten in a future epoch without invalidating commitments
/// already recorded on-ledger (`epoch` flag on each tag).
class PercSwitchCommitment {
  const PercSwitchCommitment._();

  static const int currentEpoch = 1;

  /// Derives a switch commitment from a base binding (transfer id, password hash, etc.).
  static String derive(String binding, {int epoch = currentEpoch}) {
    final base =
        sha256.convert(utf8.encode('perc-swc-base:$epoch:$binding')).toString();
    final switchLayer =
        sha256.convert(utf8.encode('perc-swc-switch:$base')).toString();
    return 'swc$epoch${switchLayer.substring(0, 32)}';
  }

  static bool validates(
    String? commitment,
    String binding, {
    int? requiredEpoch,
  }) {
    if (commitment == null || commitment.isEmpty) return true;
    final epoch = requiredEpoch ?? currentEpoch;
    if (!commitment.startsWith('swc$epoch')) return false;
    return commitment == derive(binding, epoch: epoch);
  }

  static String forTransferId(String transferId) => derive('transfer:$transferId');

  static String forPasswordHash(String passwordHash, String salt) =>
      derive('password:$salt:$passwordHash');

  static String forWitnessPayload({
    required String transferId,
    required int receiverScenarioBlock,
    required bool senderCanDebit,
  }) =>
      derive(
        'witness:$transferId:$receiverScenarioBlock:${senderCanDebit ? 1 : 0}',
      );
}