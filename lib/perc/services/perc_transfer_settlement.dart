import '../models/perc_pending_inbound_transfer.dart';

/// When a pending transfer is being settled.
enum PercTransferSettlementPhase {
  /// Recipient advanced a scenario block on this device.
  recipientScenario,

  /// Sender device is merging receiver state after a remote scenario.
  senderPeerReconcile,
}

/// Effects to apply atomically on the local ledger.
class PercTransferSettlementEffects {
  const PercTransferSettlementEffects({
    required this.shouldSettle,
    this.debitSender = false,
    this.creditReceiver = false,
    this.removePending = false,
    this.provisionalReceiverCredit = false,
  });

  final bool shouldSettle;
  final bool debitSender;
  final bool creditReceiver;
  final bool removePending;

  /// Cross-device receiver credit pending sender debit confirmation.
  final bool provisionalReceiverCredit;

  static const none = PercTransferSettlementEffects(shouldSettle: false);
}

/// Pure settlement policy — receiver credit and pending removal only when
/// sender funds are attested (local balance or fresh peer relay).
class PercTransferSettlementDecision {
  static PercTransferSettlementEffects evaluate({
    required PercTransferSettlementPhase phase,
    required bool senderIsLocalWallet,
    required bool senderCanDebit,
  }) {
    switch (phase) {
      case PercTransferSettlementPhase.senderPeerReconcile:
        if (!senderIsLocalWallet || !senderCanDebit) {
          return PercTransferSettlementEffects.none;
        }
        return const PercTransferSettlementEffects(
          shouldSettle: true,
          debitSender: true,
          removePending: true,
        );
      case PercTransferSettlementPhase.recipientScenario:
        if (!senderCanDebit) return PercTransferSettlementEffects.none;
        if (senderIsLocalWallet) {
          return const PercTransferSettlementEffects(
            shouldSettle: true,
            debitSender: true,
            creditReceiver: true,
            removePending: true,
          );
        }
        return const PercTransferSettlementEffects(
          shouldSettle: true,
          creditReceiver: true,
          removePending: true,
          provisionalReceiverCredit: true,
        );
    }
  }

  /// Whether [pending] is an outbound hold owned by a local sender wallet.
  static bool isLocalOutboundHold({
    required PercPendingInboundTransfer pending,
    required bool Function(String username) senderIsLocalWallet,
  }) =>
      senderIsLocalWallet(pending.fromUsername);

  /// Applies [effects] via callbacks — all credit/debit paths share one gate.
  static bool applyTransferSettlement({
    required PercTransferSettlementEffects effects,
    required bool Function() debitSender,
    required bool Function() creditReceiver,
    required void Function() removePending,
    void Function()? markProvisional,
  }) {
    if (!effects.shouldSettle) return false;

    if (effects.debitSender && !debitSender()) return false;

    if (effects.creditReceiver && !creditReceiver()) return false;

    if (effects.provisionalReceiverCredit) {
      markProvisional?.call();
    }

    if (effects.removePending) {
      removePending();
    }
    return true;
  }
}