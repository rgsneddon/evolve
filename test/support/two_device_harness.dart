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

  /// Each device learns the other wallet's address for sends and relay merge.
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

  /// Simulates commitAfterSend push delivery to recipient rendezvous slot.
  void pushSendToReceiver() {
    receiver.ingestInboundTransferInitiation(sender);
  }

  void relayInitiationToReceiver() => pushSendToReceiver();

  /// Simulates rendezvous poll / mergeRelay (no explicit ingest call).
  void pollRelayToReceiver() {
    receiver.mergeNetworkStateFromPeer(sender);
  }

  void refreshSenderSnapshotOnReceiver() {
    receiver.mergeNetworkStateFromPeer(sender);
  }

  void mergeSenderFromReceiver() {
    sender.mergeNetworkStateFromPeer(receiver);
  }

  /// Receiver scenario with fresh sender peer attestation (not stale cache).
  void receiverScenario() {
    receiver.advanceScenarioBlock(
      receiverUser,
      senderPeerAtSettlement: sender,
    );
  }

  /// Full cross-device settlement: scenario → sender debit → confirm on receiver.
  void crossDeviceScenarioAndSettle() {
    receiverScenario();
    mergeSenderFromReceiver();
    receiver.mergeNetworkStateFromPeer(sender);
  }
}