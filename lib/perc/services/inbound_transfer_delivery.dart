/// How an outbound transfer is delivered to the recipient.
enum InboundDeliveryMode {
  /// Same-device recipient with local password — credit in one block.
  instantLocal,

  /// Cross-device relay path — credit when sender ledger is ingested.
  onRelay,

  /// Recipient offline / remote stub — pending until relay or revert window.
  queueForRevert,
}

class InboundTransferDeliveryPlan {
  const InboundTransferDeliveryPlan({
    required this.mode,
    required this.addToPendingQueue,
    required this.walletStatusKey,
  });

  final InboundDeliveryMode mode;
  final bool addToPendingQueue;

  /// Ephemeral wallet status key after send (`wallet_status_sent_*`).
  final String walletStatusKey;

  static InboundTransferDeliveryPlan planSend({
    required bool isLocalSettleableRecipient,
  }) {
    if (isLocalSettleableRecipient) {
      return const InboundTransferDeliveryPlan(
        mode: InboundDeliveryMode.instantLocal,
        addToPendingQueue: false,
        walletStatusKey: 'wallet_status_sent_instant',
      );
    }
    return const InboundTransferDeliveryPlan(
      mode: InboundDeliveryMode.queueForRevert,
      addToPendingQueue: true,
      walletStatusKey: 'wallet_status_sent_queued',
    );
  }

  static const relay = InboundTransferDeliveryPlan(
    mode: InboundDeliveryMode.onRelay,
    addToPendingQueue: false,
    walletStatusKey: 'wallet_status_sent_pending',
  );
}