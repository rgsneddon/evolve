import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_transfer_settlement.dart';

void main() {
  group('PercTransferSettlementDecision', () {
    test('recipientScenario defers when sender cannot debit (local)', () {
      final d = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.recipientScenario,
        senderIsLocalWallet: true,
        senderCanDebit: false,
      );
      expect(d.shouldSettle, isFalse);
      expect(d.creditReceiver, isFalse);
    });

    test('recipientScenario defers when sender cannot debit (cross-device)', () {
      final d = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.recipientScenario,
        senderIsLocalWallet: false,
        senderCanDebit: false,
      );
      expect(d.shouldSettle, isFalse);
      expect(d.creditReceiver, isFalse);
    });

    test('recipientScenario credits cross-device only with peer attestation', () {
      final d = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.recipientScenario,
        senderIsLocalWallet: false,
        senderCanDebit: true,
      );
      expect(d.shouldSettle, isTrue);
      expect(d.creditReceiver, isTrue);
      expect(d.debitSender, isFalse);
      expect(d.removePending, isTrue);
    });

    test('senderPeerReconcile defers when sender cannot debit', () {
      final d = PercTransferSettlementDecision.evaluate(
        phase: PercTransferSettlementPhase.senderPeerReconcile,
        senderIsLocalWallet: true,
        senderCanDebit: false,
      );
      expect(d.shouldSettle, isFalse);
      expect(d.removePending, isFalse);
    });
  });
}