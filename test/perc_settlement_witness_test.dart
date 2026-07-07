import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_settlement_witness.dart';

void main() {
  group('planSettlement', () {
    test('local happy path debits sender and credits receiver', () {
      final plan = planSettlement(
        phase: SettlementPhase.transferCredit,
        senderIsLocalWallet: true,
        senderCanDebit: true,
        senderPeerProvided: true,
        remoteWitnessPresent: false,
        remoteSettledWithoutPending: false,
      );
      expect(plan.deferred, isFalse);
      expect(plan.debitSender, isTrue);
      expect(plan.creditReceiver, isTrue);
      expect(plan.emitWitness, isFalse);
      expect(plan.removePending, isTrue);
    });

    test('cross-device with fresh peer emits witness without local debit', () {
      final plan = planSettlement(
        phase: SettlementPhase.transferCredit,
        senderIsLocalWallet: false,
        senderCanDebit: true,
        senderPeerProvided: true,
        remoteWitnessPresent: false,
        remoteSettledWithoutPending: false,
      );
      expect(plan.creditReceiver, isTrue);
      expect(plan.debitSender, isFalse);
      expect(plan.emitWitness, isTrue);
    });

    test('cross-device without peer is deferred', () {
      final plan = planSettlement(
        phase: SettlementPhase.transferCredit,
        senderIsLocalWallet: false,
        senderCanDebit: false,
        senderPeerProvided: false,
        remoteWitnessPresent: false,
        remoteSettledWithoutPending: false,
      );
      expect(plan.deferred, isTrue);
      expect(plan.creditReceiver, isFalse);
    });

    test('insufficient funds at scenario is deferred', () {
      final plan = planSettlement(
        phase: SettlementPhase.transferCredit,
        senderIsLocalWallet: true,
        senderCanDebit: false,
        senderPeerProvided: true,
        remoteWitnessPresent: false,
        remoteSettledWithoutPending: false,
      );
      expect(plan.deferred, isTrue);
    });

    test('sender reconcile debits when witness present', () {
      final plan = planSettlement(
        phase: SettlementPhase.senderPeerReconcile,
        senderIsLocalWallet: true,
        senderCanDebit: true,
        senderPeerProvided: true,
        remoteWitnessPresent: true,
        remoteSettledWithoutPending: false,
      );
      expect(plan.debitSender, isTrue);
      expect(plan.removePending, isTrue);
      expect(plan.creditReceiver, isFalse);
    });

    test('sender reconcile defers when cannot debit', () {
      final plan = planSettlement(
        phase: SettlementPhase.senderPeerReconcile,
        senderIsLocalWallet: true,
        senderCanDebit: false,
        senderPeerProvided: true,
        remoteWitnessPresent: true,
        remoteSettledWithoutPending: false,
      );
      expect(plan.deferred, isTrue);
    });
  });
}