import '../perc_chain_constants.dart';
import 'perc_chain_tip.dart';
import 'perc_ledger.dart';

/// JSON payloads exchanged between Perccent wallet nodes.
class PercNetworkStatus {
  const PercNetworkStatus({
    required this.evolutionaryChainId,
    required this.blockHeight,
    required this.tipHash,
    required this.revision,
    this.sessionUsername,
    this.endpoint,
  });

  final String evolutionaryChainId;
  final int blockHeight;
  final String tipHash;
  final int revision;
  final String? sessionUsername;
  final String? endpoint;

  Map<String, dynamic> toJson() => {
        'evolutionaryChainId': evolutionaryChainId,
        'blockHeight': blockHeight,
        'tipHash': tipHash,
        'revision': revision,
        if (sessionUsername != null) 'sessionUsername': sessionUsername,
        if (endpoint != null) 'endpoint': endpoint,
      };

  factory PercNetworkStatus.fromJson(Map<String, dynamic> json) =>
      PercNetworkStatus(
        evolutionaryChainId: json['evolutionaryChainId'] as String,
        blockHeight: json['blockHeight'] as int? ?? 0,
        tipHash: json['tipHash'] as String? ?? '',
        revision: json['revision'] as int? ?? 0,
        sessionUsername: json['sessionUsername'] as String?,
        endpoint: json['endpoint'] as String?,
      );

  static PercNetworkStatus fromLedger(
    PercLedger ledger, {
    required int revision,
    String? endpoint,
  }) =>
      PercNetworkStatus(
        evolutionaryChainId: ledger.evolutionaryChainId.isEmpty
            ? PercChainConstants.evolutionaryChainId
            : ledger.evolutionaryChainId,
        blockHeight: PercChainTip.height(ledger),
        tipHash: PercChainTip.hash(ledger),
        revision: revision,
        sessionUsername: ledger.sessionUsername,
        endpoint: endpoint,
      );
}

enum PercNetworkSyncState {
  idle,
  syncing,
  synced,
  heightMismatch,
}