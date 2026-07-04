import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/analysis_mode.dart';
import '../models/perc_evolution_step.dart';
import '../models/perc_side_chain.dart';
import '../perc_app_version.dart';
import '../services/perc_beam_privacy.dart';
import '../models/perc_amount.dart';
import '../models/perc_block.dart';
import '../models/perc_faucet_credit_result.dart';
import '../models/perc_pending_inbound_transfer.dart';
import '../models/perc_transaction.dart';

import '../perc_chain_constants.dart';
import '../services/perc_auth.dart';
import '../services/perc_faucet.dart';
import '../services/perc_faucet_cooldown.dart';
import '../services/perc_inflation.dart';
import '../services/perc_ledger.dart';
import '../models/perc_peer_node.dart';
import '../services/perc_ledger_hub.dart';
import '../services/perc_network_protocol.dart';
import '../services/perc_wallet_store.dart';
import '../services/perc_wallet_store_factory.dart';

class PercWalletProvider extends ChangeNotifier {
  PercWalletProvider({PercWalletStore? store})
      : _store = store ?? createPercWalletStore() {
    PercLedgerHub.instance.addListener(_onHubLedgerChanged);
  }

  final PercWalletStore _store;
  PercLedger get _ledger => PercLedgerHub.instance.ledger;
  bool _ready = false;
  PercFaucetReward? lastReward;
  String? statusMessage;
  String? errorMessage;
  PercFaucetCreditResult? _pendingCooldownPopup;
  bool _pendingLaunchBalloon = false;
  bool _pendingGenesisRenewalNotice = false;

  bool get isReady => _ready;
  bool get isBlockchainLaunched => _ledger.isBlockchainLaunched;
  bool get isLoggedIn => _ledger.isLoggedIn;
  String? get loggedInUsername => _ledger.sessionUsername;
  bool get needsTreasuryPassword => _ledger.treasuryNeedsPasswordSetup();

  /// True when any non-treasury wallet has been registered on this device.
  bool get hasNonTreasuryAccounts => _ledger.accounts.keys.any(
        (name) => name != PercChainConstants.treasuryUsername,
      );

  /// User may use Evolve only after register/login generates a Perccent address.
  bool get hasAppAccess => isLoggedIn && address.isNotEmpty;

  PercAmount get balance => _ledger.sessionBalance;
  PercAmount get cumulativeStaking =>
      _ledger.sessionAccount?.cumulativeStakingEarned ?? PercAmount.zero;
  String get address => _ledger.sessionAccount?.address ?? '';
  List<PercTransaction> get transactions =>
      List.unmodifiable(_ledger.sessionAccount?.transactions ?? const []);
  int get blockHeight => _ledger.blockHeight;
  List<PercBlock> get blocks => _ledger.chainBlocks;
  double get treasuryProgress => _ledger.treasuryProgress;
  PercAmount get treasuryMinted => _ledger.cumulativeTreasuryMinted;
  PercAmount get treasuryRemaining => _ledger.treasuryRemaining;
  PercAmount get treasuryPool => _ledger.treasuryBalance;
  PercAmount get cumulativeBurnedPerc => _ledger.cumulativeBurnedPerc;
  bool get treasuryCapped => _ledger.treasuryCapped;
  int get treasuryCycle => _ledger.treasuryCycle;
  DateTime? get lastInflationEpoch => _ledger.lastInflationEpoch;
  bool get treasuryPoolCritical => _ledger.treasuryPoolCritical;
  Duration? get timeToNextInflation => _ledger.timeToNextInflation();
  bool get inflationReady =>
      PercInflation.isInflationReady(timeToNextInflation);
  bool get isTreasuryAccount =>
      loggedInUsername == PercChainConstants.treasuryUsername;
  bool get isTreasurySendLocked => _ledger.isTreasurySendLocked;
  bool get canSendFromSession =>
      isLoggedIn && !(isTreasuryAccount && isTreasurySendLocked);

  /// Every registered user can receive PERC (including locked treasury).
  bool get canReceiveFromSession => isLoggedIn;

  PercSideChainState get sideChain => PercSideChainState.fromLedger(_ledger);

  List<String> get allRegisteredWallets {
    final list = _ledger.accounts.keys.toList()..sort();
    return list;
  }

  /// Registered PERC addresses excluding the signed-in wallet — for send picker.
  List<String> get sendableAddresses {
    if (!isLoggedIn) return const [];
    final self = address;
    return allRegisteredWallets
        .where((name) => name != loggedInUsername)
        .map((name) => _ledger.account(name)?.address ?? '')
        .where((addr) => addr.isNotEmpty && addr != self)
        .toList(growable: false);
  }

  String addressForUsername(String username) =>
      _ledger.account(username)?.address ?? '';
  int get confirmationsRequired => PercChainConstants.confirmationsRequired;
  int get microblockCount => _ledger.microblockCount;
  int get totalMicroblocks => _ledger.totalMicroblocks;
  int get microblocksPerBlock => _ledger.microblocksPerBlock;
  double get microblockProgress => _ledger.microblockProgress;
  String? get lastChronofluxFingerprint => _ledger.lastChronofluxFingerprint;
  bool get isWalletMeshComplete => _ledger.isWalletMeshComplete;
  List<String> get connectedPeerWallets => _ledger.sessionConnectedPeers;
  int get connectedWalletCount => connectedPeerWallets.length;
  PercNetworkSyncState get networkSyncState =>
      PercLedgerHub.instance.network.syncState;
  int get networkBlockHeight => PercLedgerHub.instance.network.networkBlockHeight;
  bool get isNetworkSynced => PercLedgerHub.instance.network.isSyncedToNetwork;
  bool get isWalletNodeOnline => PercLedgerHub.instance.network.isNodeServing;
  String? get walletNodeEndpoint => PercLedgerHub.instance.network.nodeEndpoint;
  List<PercPeerNode> get onlineNetworkNodes =>
      PercLedgerHub.instance.network.onlineNodes;
  String get evolutionaryChainId => _ledger.evolutionaryChainId;
  String get chronofluxPrincipiaId => _ledger.chronofluxPrincipiaId;
  String get connectedAppVersion => _ledger.connectedAppVersion;
  String get currentAppVersion => PercAppVersion.current;
  List<String> get evolvedAppVersions => List.unmodifiable(_ledger.evolvedAppVersions);
  List<PercEvolutionStep> get evolutionSteps =>
      List.unmodifiable(_ledger.evolutionSteps);
  int get evolutionEpoch => _ledger.evolutionEpoch;
  bool get isOnEvolutionaryChain => _ledger.isOnEvolutionaryChain;
  Duration? get averageTimePerBlock => _ledger.averageTimePerBlock;

  List<PercPendingInboundTransfer> get pendingInboundTransfers =>
      isLoggedIn
          ? _ledger.pendingInboundFor(loggedInUsername!)
          : const [];

  void _onHubLedgerChanged() => notifyListeners();

  Duration? get faucetCooldownRemaining {
    if (!isLoggedIn) return null;
    return _ledger.faucetCooldownRemaining(_ledger.sessionUsername!);
  }

  PercFaucetCreditResult? takeCooldownPopup() {
    final popup = _pendingCooldownPopup;
    _pendingCooldownPopup = null;
    return popup;
  }

  bool takeBlockchainLaunchBalloon() {
    if (!_pendingLaunchBalloon) return false;
    _pendingLaunchBalloon = false;
    return true;
  }

  bool takeGenesisRenewalNotice() {
    if (!_pendingGenesisRenewalNotice) return false;
    _pendingGenesisRenewalNotice = false;
    return true;
  }

  void _captureTreasuryLaunchEvent() {
    if (_ledger.consumeBlockchainLaunchEvent()) {
      _pendingLaunchBalloon = true;
    }
  }

  void _captureGenesisRenewalEvent() {
    if (_ledger.consumeGenesisRenewalEvent()) {
      _pendingGenesisRenewalNotice = true;
    }
  }

  Future<void> initialize() async {
    await PercLedgerHub.instance.initialize(_store);
    _ledger.refreshPendingInboundTransfers();
    _ready = true;
    notifyListeners();
  }

  Future<void> setupTreasuryPassword(String password) async {
    _clearMessages();
    try {
      _ledger.setupTreasuryPassword(password);
      _ledger.login(PercChainConstants.treasuryUsername, password);
      await PercLedgerHub.instance.onWalletSessionStarted(
        PercChainConstants.treasuryUsername,
      );
      _captureTreasuryLaunchEvent();
      statusMessage = 'Treasury secured — blockchain launched';
      notifyListeners();
      await _commit();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    }
  }

  Future<void> register(String username, String password) async {
    _clearMessages();
    try {
      _ledger.register(username, password);
      _ledger.login(username, password);
      await PercLedgerHub.instance.onWalletSessionStarted(username);
      statusMessage = 'Account created';
      notifyListeners();
      await _commit();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _clearMessages();
    try {
      _ledger.login(username, password);
      await PercLedgerHub.instance.onWalletSessionStarted(username);
      _captureTreasuryLaunchEvent();
      statusMessage = 'Signed in as ${_ledger.sessionUsername}';
      notifyListeners();
      await _commit();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final username = _ledger.sessionUsername;
    _ledger.logout();
    if (username != null) {
      await PercLedgerHub.instance.onWalletSessionEnded(username);
    }
    lastReward = null;
    _clearMessages();
    notifyListeners();
    await _commit();
  }

  Future<void> send({
    required String toAddress,
    required String amountText,
    String? memo,
  }) async {
    _clearMessages();
    if (!isLoggedIn) {
      errorMessage =
          'Sign in to send ${PercChainConstants.currencyName}';
      notifyListeners();
      return;
    }
    if (!canSendFromSession) {
      errorMessage =
          'Treasury ${PercChainConstants.treasuryUsername} is locked — outbound sends disabled after blockchain launch';
      notifyListeners();
      return;
    }
    final amount = PercAmount.tryParseDisplay(amountText);
    if (amount == null) {
      errorMessage =
          'Enter a valid ${PercChainConstants.currencySymbol} amount (up to 8 decimal places)';
      notifyListeners();
      return;
    }
    if (!amount.isAtLeastSmallestUnit) {
      errorMessage =
          'Minimum send is ${PercChainConstants.centValueInPerc} ${PercChainConstants.currencySymbol} (1 cent)';
      notifyListeners();
      return;
    }
    final fee = PercChainConstants.sendTransactionFee;
    final totalDebit = amount + fee;
    if (balance < totalDebit) {
      errorMessage =
          'Insufficient balance — need ${totalDebit.displayFixed8} ${PercChainConstants.currencySymbol} '
          '(${amount.displayFixed8} + ${fee.displayFixed8} network fee)';
      notifyListeners();
      return;
    }
    final addrErr = PercAuth.validateAddress(toAddress);
    if (addrErr != null) {
      errorMessage = addrErr;
      notifyListeners();
      return;
    }
    final normalizedAddress = PercAuth.normalizeAddress(toAddress);
    try {
      final recipient = _ledger.accountForAddress(normalizedAddress)?.username;
      final recipientOnline =
          recipient != null && _ledger.isWalletOnlineOnNetwork(recipient);
      _ledger.send(
        fromUsername: _ledger.sessionUsername!,
        toAddress: normalizedAddress,
        amount: amount,
        memo: memo,
      );
      _captureGenesisRenewalEvent();
      final dest = PercBeamPrivacy.shieldAddress(normalizedAddress);
      if (_pendingGenesisRenewalNotice) {
        statusMessage =
            'Genesis block — treasury cycle $treasuryCycle renewed (283M ${PercChainConstants.currencySymbol} ${PercChainConstants.currencyName})';
      } else if (recipientOnline) {
        statusMessage =
            'Sent ${amount.displayFixed8} ${PercChainConstants.currencySymbol} to $dest '
            '(network fee ${fee.displayFixed8} ${PercChainConstants.currencySymbol})';
      } else {
        statusMessage =
            'Sent ${amount.displayFixed8} ${PercChainConstants.currencySymbol} to $dest '
            '(network fee ${fee.displayFixed8} ${PercChainConstants.currencySymbol}) — '
            'delivers when they sign in within ${_formatReceiveDelay()}, otherwise returns to your wallet';
      }
      notifyListeners();
      await _commit();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    }
  }

  Future<PercFaucetCreditResult?> creditAnalysis({
    required AnalysisMode mode,
    required double outcomeScore,
    String? memo,
    double? continuumScs,
    double? vortexScs,
    double? shearScs,
    double? resistanceScs,
    double? flowScs,
  }) async {
    return creditScenario(
      outcomeScore: outcomeScore,
      memo: memo,
      analysisMode: mode,
      continuumScs: continuumScs,
      vortexScs: vortexScs,
      shearScs: shearScs,
      resistanceScs: resistanceScs,
      flowScs: flowScs,
    );
  }

  Future<PercFaucetCreditResult?> creditScenario({
    required double outcomeScore,
    String? memo,
    AnalysisMode? analysisMode,
    double? continuumScs,
    double? vortexScs,
    double? shearScs,
    double? resistanceScs,
    double? flowScs,
  }) async {
    final score = outcomeScore;
    if (!_ready || !isLoggedIn) return null;
    _clearMessages();
    try {
      final label = memo ??
          (analysisMode == AnalysisMode.cohesionScore
              ? 'Social cohesion score analysis'
              : 'Percent chance analysis');
      final result = _ledger.creditScenario(
        username: _ledger.sessionUsername!,
        percentChance: score,
        scenarioLabel: label,
        continuumScs: continuumScs ?? score,
        vortexScs: vortexScs,
        shearScs: shearScs,
        resistanceScs: resistanceScs,
        flowScs: flowScs,
      );

      _captureGenesisRenewalEvent();

      if (result.showCooldownPopup) {
        _pendingCooldownPopup = result;
        statusMessage = _pendingGenesisRenewalNotice
            ? 'Genesis block — treasury cycle $treasuryCycle renewed (283M ${PercChainConstants.currencySymbol} ${PercChainConstants.currencyName})'
            : null;
        notifyListeners();
        await _commit();
        return result;
      }

      if (result.status == PercFaucetCreditStatus.credited &&
          result.reward != null) {
        lastReward = result.reward;
        statusMessage = _pendingGenesisRenewalNotice
            ? 'Genesis block — treasury cycle $treasuryCycle renewed (283M ${PercChainConstants.currencySymbol} ${PercChainConstants.currencyName})'
            : '+${result.reward!.total.displayFixed8} ${PercChainConstants.currencySymbol}';
        notifyListeners();
        await _commit();
        return result;
      }

      if (result.status == PercFaucetCreditStatus.blockchainNotLaunched) {
        statusMessage =
            'Blockchain awaiting treasurer first sign-in';
      } else if (result.status == PercFaucetCreditStatus.treasuryEmpty) {
        statusMessage = _pendingGenesisRenewalNotice
            ? 'Genesis block — treasury cycle $treasuryCycle renewed (283M ${PercChainConstants.currencySymbol} ${PercChainConstants.currencyName})'
            : 'Treasury empty — run another scenario later';
      }
      notifyListeners();
      await _commit();
      return result;
    } catch (e) {
      statusMessage = 'Treasury cap reached';
      notifyListeners();
      return null;
    }
  }

  void _clearMessages() {
    statusMessage = null;
    errorMessage = null;
  }

  String _formatReceiveDelay() {
    const delay = PercChainConstants.walletOnlineReceiveDelay;
    if (delay.inDays >= 365) return '12 months';
    if (delay.inDays >= 30) return '${delay.inDays ~/ 30} months';
    if (delay.inHours >= 1) return '${delay.inHours} hours';
    return '${delay.inSeconds} seconds';
  }

  Future<void> _commit() => PercLedgerHub.instance.commit();

  @override
  void dispose() {
    PercLedgerHub.instance.removeListener(_onHubLedgerChanged);
    super.dispose();
  }
}