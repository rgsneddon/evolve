import '../perc_chain_constants.dart';
import '../services/perc_auth.dart';
import '../services/perc_switch_commitment.dart';
import 'perc_amount.dart';

/// Cross-device transfer record while relay settles on the network.
/// Delivered transfers credit the recipient near-instantly on send/relay;
/// undelivered entries revert to [fromUsername] after
/// [PercChainConstants.walletInboundRevertWindow] from [sentAt].
class PercPendingInboundTransfer {
  PercPendingInboundTransfer({
    required this.id,
    required this.fromUsername,
    required this.toUsername,
    required this.amount,
    required this.sentAt,
    PercAmount? fee,
    this.memo,
    this.toAddress,
    this.recipientBroughtOnlineAt,
    String? switchCommitment,
  })  : fee = fee ?? PercChainConstants.sendTransactionFee,
        switchCommitment = switchCommitment ??
            PercSwitchCommitment.forTransferId(id);

  final String id;
  final String fromUsername;
  final String toUsername;
  /// Authoritative recipient wallet address — inbound matching uses this, not username alone.
  final String? toAddress;
  final PercAmount amount;
  final PercAmount fee;
  final DateTime sentAt;
  final String? memo;
  DateTime? recipientBroughtOnlineAt;
  final String switchCommitment;

  PercAmount get totalHold => amount + fee;

  bool get switchCommitmentValid =>
      PercSwitchCommitment.validates(switchCommitment, 'transfer:$id');

  String normalizedToAddress({String fallback = ''}) {
    final raw = toAddress?.trim();
    if (raw != null && raw.isNotEmpty) {
      return PercAuth.normalizeAddress(raw);
    }
    return PercAuth.normalizeAddress(fallback);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUsername': fromUsername,
        'toUsername': toUsername,
        if (toAddress != null && toAddress!.isNotEmpty) 'toAddress': toAddress,
        'amount': amount.toJson(),
        'fee': fee.toJson(),
        'sentAt': sentAt.toIso8601String(),
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
        if (recipientBroughtOnlineAt != null)
          'recipientBroughtOnlineAt':
              recipientBroughtOnlineAt!.toIso8601String(),
        'switchCommitment': switchCommitment,
      };

  factory PercPendingInboundTransfer.fromJson(Map<String, dynamic> json) {
    final pending = PercPendingInboundTransfer(
      id: json['id'] as String,
      fromUsername: json['fromUsername'] as String,
      toUsername: json['toUsername'] as String,
      toAddress: json['toAddress'] as String?,
      amount: PercAmount.fromJson(json['amount'] as Map<String, dynamic>),
      fee: json['fee'] == null
          ? null
          : PercAmount.fromJson(json['fee'] as Map<String, dynamic>),
      sentAt: DateTime.parse(json['sentAt'] as String),
      memo: json['memo'] as String?,
      switchCommitment: json['switchCommitment'] as String?,
    );
    if (json['recipientBroughtOnlineAt'] != null) {
      pending.recipientBroughtOnlineAt =
          DateTime.parse(json['recipientBroughtOnlineAt'] as String);
    }
    return pending;
  }
}