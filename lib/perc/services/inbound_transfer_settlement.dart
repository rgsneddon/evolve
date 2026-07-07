import 'perc_settlement_witness.dart';

/// What caused inbound transfer settlement to be considered.
enum SettlementTrigger {
  /// Same-device send settled inline in [PercLedger.send].
  instantLocal,

  /// Cross-device relay ingest ([PercLedger.applyInboundRelayFromSender]).
  relay,

  /// Expired pending entry past [PercChainConstants.walletInboundRevertWindow].
  revertExpired,

  /// Scenario block advance — never settles transfers (height only).
  scenarioAdvance,
}

enum InboundSettlementOpKind {
  creditReceiver,
  debitSender,
  emitWitness,
  removePending,
  revertToSender,
}

class InboundSettlementOp {
  const InboundSettlementOp(this.kind);

  final InboundSettlementOpKind kind;
}

/// Pure reducer for inbound transfer settlement — one trigger set, no scenario credit.
class InboundTransferSettlement {
  const InboundTransferSettlement._();

  /// Returns ordered ledger ops for one pending transfer evaluation.
  static List<InboundSettlementOp> plan({
    required SettlementTrigger trigger,
    required bool senderIsLocalWallet,
    required bool senderCanDebit,
    required bool senderPeerProvided,
    required bool withinRevertWindow,
    required bool isExpired,
    required bool remoteWitnessPresent,
    required bool remoteSettledWithoutPending,
  }) {
    if (trigger == SettlementTrigger.scenarioAdvance) {
      return const [];
    }

    if (trigger == SettlementTrigger.revertExpired) {
      if (!isExpired) return const [];
      return const [InboundSettlementOp(InboundSettlementOpKind.revertToSender)];
    }

    if (!withinRevertWindow) return const [];

    final phase = trigger == SettlementTrigger.instantLocal ||
            trigger == SettlementTrigger.relay
        ? SettlementPhase.transferCredit
        : SettlementPhase.senderPeerReconcile;

    final settlement = planSettlement(
      phase: phase,
      senderIsLocalWallet: senderIsLocalWallet,
      senderCanDebit: senderCanDebit,
      senderPeerProvided: senderPeerProvided,
      remoteWitnessPresent: remoteWitnessPresent,
      remoteSettledWithoutPending: remoteSettledWithoutPending,
    );

    if (!settlement.shouldApply) return const [];

    final ops = <InboundSettlementOp>[];
    if (settlement.creditReceiver) {
      ops.add(const InboundSettlementOp(InboundSettlementOpKind.creditReceiver));
    }
    if (settlement.debitSender) {
      ops.add(const InboundSettlementOp(InboundSettlementOpKind.debitSender));
    }
    if (settlement.emitWitness) {
      ops.add(const InboundSettlementOp(InboundSettlementOpKind.emitWitness));
    }
    if (settlement.removePending) {
      ops.add(const InboundSettlementOp(InboundSettlementOpKind.removePending));
    }
    return ops;
  }

  static bool includesCredit(List<InboundSettlementOp> ops) =>
      ops.any((o) => o.kind == InboundSettlementOpKind.creditReceiver);
}