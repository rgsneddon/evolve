import '../perc_chain_constants.dart';
import 'perc_amount.dart';
import 'perc_transaction.dart';

class PercBlock {
  const PercBlock({
    required this.index,
    required this.timestamp,
    required this.transactions,
    required this.treasuryEmitted,
    this.scenarioLabel,
    this.triggerUsername,
    this.treasuryCycle = 1,
    this.isGenesisRenewal = false,
    this.confirmations = PercChainConstants.confirmationsRequired,
  });

  final int index;
  final DateTime timestamp;
  final List<PercTransaction> transactions;
  final PercAmount treasuryEmitted;
  final String? scenarioLabel;
  final String? triggerUsername;
  final int treasuryCycle;
  final bool isGenesisRenewal;
  final int confirmations;

  bool get isConfirmed =>
      confirmations >= PercChainConstants.confirmationsRequired;

  Map<String, dynamic> toJson() => {
        'index': index,
        'timestamp': timestamp.toIso8601String(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'treasuryEmitted': treasuryEmitted.toJson(),
        if (scenarioLabel != null) 'scenarioLabel': scenarioLabel,
        if (triggerUsername != null) 'triggerUsername': triggerUsername,
        if (treasuryCycle != 1) 'treasuryCycle': treasuryCycle,
        if (isGenesisRenewal) 'isGenesisRenewal': isGenesisRenewal,
        if (confirmations != PercChainConstants.confirmationsRequired)
          'confirmations': confirmations,
      };

  factory PercBlock.fromJson(Map<String, dynamic> json) => PercBlock(
        index: json['index'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        transactions: (json['transactions'] as List<dynamic>)
            .map((e) => PercTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        treasuryEmitted:
            PercAmount.fromJson(json['treasuryEmitted'] as Map<String, dynamic>),
        scenarioLabel: json['scenarioLabel'] as String?,
        triggerUsername: json['triggerUsername'] as String?,
        treasuryCycle: json['treasuryCycle'] as int? ?? 1,
        isGenesisRenewal: json['isGenesisRenewal'] as bool? ?? false,
        confirmations: json['confirmations'] as int? ??
            PercChainConstants.confirmationsRequired,
      );
}