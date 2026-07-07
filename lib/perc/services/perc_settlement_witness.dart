import '../models/perc_pending_inbound_transfer.dart';
import 'perc_switch_commitment.dart';

/// Gossip-mergeable witness that a receiver wallet credited an inbound transfer.
class PercSettlementWitness {
  PercSettlementWitness({
    required this.transferId,
    required this.receiverScenarioBlock,
    required this.senderCanDebit,
    required this.witnessedAt,
    String? switchCommitment,
  }) : switchCommitment = switchCommitment ??
            PercSwitchCommitment.forWitnessPayload(
              transferId: transferId,
              receiverScenarioBlock: receiverScenarioBlock,
              senderCanDebit: senderCanDebit,
            );

  final String transferId;
  final int receiverScenarioBlock;
  final bool senderCanDebit;
  final DateTime witnessedAt;
  final String switchCommitment;

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'receiverScenarioBlock': receiverScenarioBlock,
        'senderCanDebit': senderCanDebit,
        'witnessedAt': witnessedAt.toIso8601String(),
        'switchCommitment': switchCommitment,
      };

  factory PercSettlementWitness.fromJson(Map<String, dynamic> json) {
    final transferId = json['transferId'] as String;
    final receiverScenarioBlock = json['receiverScenarioBlock'] as int? ?? 0;
    final senderCanDebit = json['senderCanDebit'] as bool? ?? false;
    return PercSettlementWitness(
      transferId: transferId,
      receiverScenarioBlock: receiverScenarioBlock,
      senderCanDebit: senderCanDebit,
      witnessedAt: DateTime.parse(json['witnessedAt'] as String),
      switchCommitment: json['switchCommitment'] as String?,
    );
  }

  bool get switchCommitmentValid =>
      PercSwitchCommitment.validates(
        switchCommitment,
        'witness:$transferId:$receiverScenarioBlock:${senderCanDebit ? 1 : 0}',
      );
}

enum SettlementPhase {
  /// Receiver credits inbound PERC (same-device or cross-device relay).
  transferCredit,
  senderPeerReconcile,
}

/// Pure settlement plan — one relay-visible transition per phase.
class SettlementPlan {
  const SettlementPlan({
    this.deferred = false,
    this.creditReceiver = false,
    this.debitSender = false,
    this.emitWitness = false,
    this.removePending = false,
  });

  final bool deferred;
  final bool creditReceiver;
  final bool debitSender;
  final bool emitWitness;
  final bool removePending;

  static const deferredPlan = SettlementPlan(deferred: true);

  bool get shouldApply => !deferred;
}

SettlementPlan planSettlement({
  required SettlementPhase phase,
  required bool senderIsLocalWallet,
  required bool senderCanDebit,
  required bool senderPeerProvided,
  required bool remoteWitnessPresent,
  required bool remoteSettledWithoutPending,
}) {
  switch (phase) {
    case SettlementPhase.transferCredit:
      if (senderIsLocalWallet) {
        if (!senderCanDebit) return SettlementPlan.deferredPlan;
        return const SettlementPlan(
          creditReceiver: true,
          debitSender: true,
          removePending: true,
        );
      }
      if (!senderPeerProvided || !senderCanDebit) {
        return SettlementPlan.deferredPlan;
      }
      return const SettlementPlan(
        creditReceiver: true,
        emitWitness: true,
        removePending: true,
      );
    case SettlementPhase.senderPeerReconcile:
      if (!senderIsLocalWallet || !senderCanDebit) {
        return SettlementPlan.deferredPlan;
      }
      if (!remoteWitnessPresent && !remoteSettledWithoutPending) {
        return SettlementPlan.deferredPlan;
      }
      return const SettlementPlan(
        debitSender: true,
        removePending: true,
      );
  }
}

bool isLocalOutboundHold({
  required PercPendingInboundTransfer pending,
  required bool Function(String username) senderIsLocalWallet,
}) =>
    senderIsLocalWallet(pending.fromUsername);