import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

/// Two independent [PercLedger] instances — one wallet per device (BeamMW).
class TwoDeviceHarness {
  TwoDeviceHarness._({
    required this.sender,
    required this.receiver,
    required this.senderUser,
    required this.receiverUser,
    required this.password,
  });

  final PercLedger sender;
  final PercLedger receiver;
  final String senderUser;
  final String receiverUser;
  final String password;

  static void seed(PercLedger ledger) {
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password123');
    ledger.launchBlockchain();
    ledger.consumeBlockchainLaunchEvent();
  }

  static TwoDeviceHarness create({
    String senderUser = 'alice',
    String receiverUser = 'bob',
    String password = 'password123',
  }) {
    final sender = PercLedger.empty();
    final receiver = PercLedger.empty();
    seed(sender);
    seed(receiver);
    sender.register(senderUser, password);
    receiver.register(receiverUser, password);
    return TwoDeviceHarness._(
      sender: sender,
      receiver: receiver,
      senderUser: senderUser,
      receiverUser: receiverUser,
      password: password,
    );
  }

  void linkDevices() {
    sender.mergeDiscoverableAccounts(receiver);
    receiver.mergeDiscoverableAccounts(sender);
  }

  String get receiverAddress => receiver.account(receiverUser)!.address;

  void fundSender({double percentChance = 50}) {
    sender.creditScenario(username: senderUser, percentChance: percentChance);
  }

  void loginSender() => sender.login(senderUser, password);
  void loginReceiver() => receiver.login(receiverUser, password);

  void send(PercAmount amount, {bool deliverInstantly = false}) {
    sender.send(
      fromUsername: senderUser,
      toAddress: receiverAddress,
      amount: amount,
      deliverInstantly: deliverInstantly,
    );
  }

  /// Models [PercLedgerHub.commitAfterSend] → push → [applyInboundRelayFromSender].
  void sendAndRelay(PercAmount amount, {bool deliverInstantly = false}) {
    send(amount, deliverInstantly: deliverInstantly);
    pushSendToReceiver();
  }

  /// commitAfterSend push delivery → [applyInboundRelayFromSender].
  void pushSendToReceiver() {
    receiver.applyInboundRelayFromSender(sender);
  }

  void relayInitiationToReceiver() => pushSendToReceiver();

  /// Rendezvous poll path — same relay applier as push.
  void pollRelayToReceiver() {
    receiver.applyInboundRelayFromSender(sender);
  }

  /// Models [propagateSettlementWitnesses] → sender [ingestSettlementWitnessFromReceiver].
  void propagateWitnessToSender() {
    sender.ingestSettlementWitnessFromReceiver(receiver);
  }

  void mergeSenderFromReceiver() => propagateWitnessToSender();

  /// Advances scenario block height only — does not settle transfers.
  void receiverScenario() {
    receiver.advanceScenarioBlock(receiverUser);
  }

  /// Relay credit + witness propagate debits sender (no scenario settlement).
  void crossDeviceScenarioAndSettle() {
    pushSendToReceiver();
    propagateWitnessToSender();
  }
}