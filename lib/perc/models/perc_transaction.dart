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

extension PercTxKindWire on PercTxKind {
  String get wireName => switch (this) {
        PercTxKind.treasuryEmission => 'treasuryEmission',
        PercTxKind.scenarioReward => 'scenarioReward',
        PercTxKind.transfer => 'transfer',
        PercTxKind.stakingReward => 'stakingReward',
        PercTxKind.genesisRenewal => 'genesisRenewal',
        PercTxKind.chronofluxMicroblock => 'chronofluxMicroblock',
      };

  static PercTxKind fromWire(String raw) => switch (raw) {
        'treasuryEmission' => PercTxKind.treasuryEmission,
        'scenarioReward' => PercTxKind.scenarioReward,
        'transfer' => PercTxKind.transfer,
        'stakingReward' => PercTxKind.stakingReward,
        'genesisRenewal' => PercTxKind.genesisRenewal,
        'chronofluxMicroblock' => PercTxKind.chronofluxMicroblock,
        _ => PercTxKind.scenarioReward,
      };
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
    this.continuumScs,
    this.vortexScs,
    this.shearScs,
    this.resistanceScs,
    this.flowScs,
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
  final double? continuumScs;
  final double? vortexScs;
  final double? shearScs;
  final double? resistanceScs;
  final double? flowScs;

  bool get isConfirmed =>
      confirmations >= PercChainConstants.confirmationsRequired;

  bool get isIncoming =>
      kind == PercTxKind.scenarioReward ||
      kind == PercTxKind.stakingReward ||
      (kind == PercTxKind.transfer && toUsername != null);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.wireName,
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
        if (continuumScs != null) 'continuumScs': continuumScs,
        if (vortexScs != null) 'vortexScs': vortexScs,
        if (shearScs != null) 'shearScs': shearScs,
        if (resistanceScs != null) 'resistanceScs': resistanceScs,
        if (flowScs != null) 'flowScs': flowScs,
      };

  factory PercTransaction.fromJson(Map<String, dynamic> json) => PercTransaction(
        id: json['id'] as String,
        kind: PercTxKindWire.fromWire(json['kind'] as String? ?? ''),
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
        continuumScs: (json['continuumScs'] as num?)?.toDouble(),
        vortexScs: (json['vortexScs'] as num?)?.toDouble(),
        shearScs: (json['shearScs'] as num?)?.toDouble(),
        resistanceScs: (json['resistanceScs'] as num?)?.toDouble(),
        flowScs: (json['flowScs'] as num?)?.toDouble(),
      );
}