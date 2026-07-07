import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/inbound_transfer_settlement.dart';

void main() {
  test('scenarioAdvance trigger produces no settlement ops', () {
    final ops = InboundTransferSettlement.plan(
      trigger: SettlementTrigger.scenarioAdvance,
      senderIsLocalWallet: true,
      senderCanDebit: true,
      senderPeerProvided: true,
      withinRevertWindow: true,
      isExpired: false,
      remoteWitnessPresent: false,
      remoteSettledWithoutPending: false,
    );
    expect(ops, isEmpty);
    expect(InboundTransferSettlement.includesCredit(ops), isFalse);
  });

  test('relay trigger credits when sender peer can debit', () {
    final ops = InboundTransferSettlement.plan(
      trigger: SettlementTrigger.relay,
      senderIsLocalWallet: false,
      senderCanDebit: true,
      senderPeerProvided: true,
      withinRevertWindow: true,
      isExpired: false,
      remoteWitnessPresent: false,
      remoteSettledWithoutPending: false,
    );
    expect(InboundTransferSettlement.includesCredit(ops), isTrue);
    expect(
      ops.map((o) => o.kind),
      contains(InboundSettlementOpKind.emitWitness),
    );
    expect(
      ops.indexWhere((o) => o.kind == InboundSettlementOpKind.creditReceiver),
      lessThan(
        ops.indexWhere((o) => o.kind == InboundSettlementOpKind.emitWitness),
      ),
    );
  });

  test('revertExpired trigger reverts only when expired', () {
    expect(
      InboundTransferSettlement.plan(
        trigger: SettlementTrigger.revertExpired,
        senderIsLocalWallet: true,
        senderCanDebit: true,
        senderPeerProvided: true,
        withinRevertWindow: false,
        isExpired: false,
        remoteWitnessPresent: false,
        remoteSettledWithoutPending: false,
      ),
      isEmpty,
    );
    final ops = InboundTransferSettlement.plan(
      trigger: SettlementTrigger.revertExpired,
      senderIsLocalWallet: true,
      senderCanDebit: true,
      senderPeerProvided: true,
      withinRevertWindow: false,
      isExpired: true,
      remoteWitnessPresent: false,
      remoteSettledWithoutPending: false,
    );
    expect(ops.single.kind, InboundSettlementOpKind.revertToSender);
  });
}