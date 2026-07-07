import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_transfer_settlement.dart';

void main() {
  group('PercTransferSettlementDecision', () {
    test('recipientScenario defers when sender cannot debit (local)', () {
      final effects = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.recipientScenario,
        senderIsLocalWallet: true,
        senderCanDebit: false,
      );
      expect(effects.shouldSettle, isFalse);
      expect(effects.creditReceiver, isFalse);
    });

    test('recipientScenario defers when sender cannot debit (cross-device)', () {
      final effects = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.recipientScenario,
        senderIsLocalWallet: false,
        senderCanDebit: false,
      );
      expect(effects.shouldSettle, isFalse);
      expect(effects.creditReceiver, isFalse);
    });

    test('recipientScenario marks cross-device credit provisional', () {
      final effects = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.recipientScenario,
        senderIsLocalWallet: false,
        senderCanDebit: true,
      );
      expect(effects.shouldSettle, isTrue);
      expect(effects.creditReceiver, isTrue);
      expect(effects.debitSender, isFalse);
      expect(effects.provisionalReceiverCredit, isTrue);
    });

    test('senderPeerReconcile defers when sender cannot debit', () {
      final effects = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.senderPeerReconcile,
        senderIsLocalWallet: true,
        senderCanDebit: false,
      );
      expect(effects.shouldSettle, isFalse);
      expect(effects.removePending, isFalse);
    });

    test('applyTransferSettlement skips credit when debit fails', () {
      var debited = false;
      var credited = false;
      final ok = PercTransferSettlementDecision.applyTransferSettlement(
        effects: const PercTransferSettlementEffects(
          shouldSettle: true,
          debitSender: true,
          creditReceiver: true,
          removePending: true,
        ),
        debitSender: () => false,
        creditReceiver: () {
          credited = true;
          return true;
        },
        removePending: () => debited = true,
      );
      expect(ok, isFalse);
      expect(credited, isFalse);
      expect(debited, isFalse);
    });
  });
}