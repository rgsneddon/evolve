import '../perc_chain_constants.dart';
import 'perc_amount.dart';

/// PERC held in escrow until the recipient runs a scenario within
/// [PercChainConstants.walletInboundRevertWindow] after [sentAt], then reverts
/// to [fromUsername] if unconfirmed.
class PercPendingInboundTransfer {
  PercPendingInboundTransfer({
    required this.id,
    required this.fromUsername,
    required this.toUsername,
    required this.amount,
    required this.sentAt,
    PercAmount? fee,
    this.memo,
    this.recipientBroughtOnlineAt,
  }) : fee = fee ?? PercChainConstants.sendTransactionFee;

  final String id;
  final String fromUsername;
  final String toUsername;
  final PercAmount amount;
  final PercAmount fee;
  final DateTime sentAt;
  final String? memo;
  DateTime? recipientBroughtOnlineAt;

  PercAmount get totalHold => amount + fee;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUsername': fromUsername,
        'toUsername': toUsername,
        'amount': amount.toJson(),
        'fee': fee.toJson(),
        'sentAt': sentAt.toIso8601String(),
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
        if (recipientBroughtOnlineAt != null)
          'recipientBroughtOnlineAt':
              recipientBroughtOnlineAt!.toIso8601String(),
      };

  factory PercPendingInboundTransfer.fromJson(Map<String, dynamic> json) {
    final pending = PercPendingInboundTransfer(
      id: json['id'] as String,
      fromUsername: json['fromUsername'] as String,
      toUsername: json['toUsername'] as String,
      amount: PercAmount.fromJson(json['amount'] as Map<String, dynamic>),
      fee: json['fee'] == null
          ? null
          : PercAmount.fromJson(json['fee'] as Map<String, dynamic>),
      sentAt: DateTime.parse(json['sentAt'] as String),
      memo: json['memo'] as String?,
    );
    if (json['recipientBroughtOnlineAt'] != null) {
      pending.recipientBroughtOnlineAt =
          DateTime.parse(json['recipientBroughtOnlineAt'] as String);
    }
    return pending;
  }
}