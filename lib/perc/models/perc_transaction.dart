import '../perc_chain_constants.dart';
import 'perc_amount.dart';

enum PercTxKind {
  treasuryEmission,
  scenarioReward,
  transfer,
  stakingReward,
  genesisRenewal,
  chronofluxMicroblock,
}

class PercTransaction {
  const PercTransaction({
    required this.id,
    required this.kind,
    required this.amount,
    required this.timestamp,
    this.fromUsername,
    this.toUsername,
    this.memo,
    this.scenarioLabel,
    this.percentChance,
    this.blockIndex,
    this.confirmations = 0,
    this.chronofluxFingerprint,
    this.microblockIndex,
  });

  final String id;
  final PercTxKind kind;
  final PercAmount amount;
  final DateTime timestamp;
  final String? fromUsername;
  final String? toUsername;
  final String? memo;
  final String? scenarioLabel;
  final double? percentChance;
  final int? blockIndex;
  final int confirmations;
  final String? chronofluxFingerprint;
  final int? microblockIndex;

  bool get isConfirmed =>
      confirmations >= PercChainConstants.confirmationsRequired;

  bool get isIncoming =>
      kind == PercTxKind.scenarioReward ||
      kind == PercTxKind.stakingReward ||
      (kind == PercTxKind.transfer && toUsername != null);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'amount': amount.toJson(),
        'timestamp': timestamp.toIso8601String(),
        if (fromUsername != null) 'fromUsername': fromUsername,
        if (toUsername != null) 'toUsername': toUsername,
        if (memo != null) 'memo': memo,
        if (scenarioLabel != null) 'scenarioLabel': scenarioLabel,
        if (percentChance != null) 'percentChance': percentChance,
        if (blockIndex != null) 'blockIndex': blockIndex,
        if (confirmations != 0) 'confirmations': confirmations,
        if (chronofluxFingerprint != null)
          'chronofluxFingerprint': chronofluxFingerprint,
        if (microblockIndex != null) 'microblockIndex': microblockIndex,
      };

  factory PercTransaction.fromJson(Map<String, dynamic> json) => PercTransaction(
        id: json['id'] as String,
        kind: PercTxKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => PercTxKind.scenarioReward,
        ),
        amount: PercAmount.fromJson(json['amount'] as Map<String, dynamic>),
        timestamp: DateTime.parse(json['timestamp'] as String),
        fromUsername: json['fromUsername'] as String?,
        toUsername: json['toUsername'] as String?,
        memo: json['memo'] as String?,
        scenarioLabel: json['scenarioLabel'] as String?,
        percentChance: (json['percentChance'] as num?)?.toDouble(),
        blockIndex: json['blockIndex'] as int?,
        confirmations: json['confirmations'] as int? ?? 0,
        chronofluxFingerprint: json['chronofluxFingerprint'] as String?,
        microblockIndex: json['microblockIndex'] as int?,
      );
}