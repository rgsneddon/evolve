import '../models/perc_pending_inbound_transfer.dart';

/// When a pending transfer is being settled.
enum PercTransferSettlementPhase {
  /// Recipient advanced a scenario block on this device.
  recipientScenario,

  /// Sender device is merging receiver state after a remote scenario.
  senderPeerReconcile,
}

/// Pure settlement policy — receiver credit and pending removal only when
/// sender debit can succeed locally, or sender wallet lives on another device.
class PercTransferSettlementDecision {
  const PercTransferSettlementDecision._({
    required this.shouldSettle,
    this.debitSender = false,
    this.creditReceiver = false,
    this.removePending = false,
  });

  final bool shouldSettle;
  final bool debitSender;
  final bool creditReceiver;
  final bool removePending;

  static const none = PercTransferSettlementDecision._(shouldSettle: false);

  static PercTransferSettlementDecision evaluate({
    required PercTransferSettlementPhase phase,
    required bool senderIsLocalWallet,
    required bool senderCanDebit,
  }) {
    switch (phase) {
      case PercTransferSettlementPhase.senderPeerReconcile:
        if (!senderIsLocalWallet || !senderCanDebit) return none;
        return const PercTransferSettlementDecision._(
          shouldSettle: true,
          debitSender: true,
          removePending: true,
        );
      case PercTransferSettlementPhase.recipientScenario:
        if (senderIsLocalWallet) {
          if (!senderCanDebit) return none;
          return const PercTransferSettlementDecision._(
            shouldSettle: true,
            debitSender: true,
            creditReceiver: true,
            removePending: true,
          );
        }
        return const PercTransferSettlementDecision._(
          shouldSettle: true,
          creditReceiver: true,
          removePending: true,
        );
    }
  }

  /// Whether [pending] is an outbound hold owned by a local sender wallet.
  static bool isLocalOutboundHold({
    required PercPendingInboundTransfer pending,
    required bool Function(String username) senderIsLocalWallet,
  }) =>
      senderIsLocalWallet(pending.fromUsername);
}