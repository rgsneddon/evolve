import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/analysis_mode.dart';
import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../models/perc_evolution_step.dart';
import '../models/perc_microblock_log_entry.dart';
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
import '../services/perc_seed_block.dart';
import '../services/perc_wallet_store.dart';
import '../services/perc_wallet_store_factory.dart';

class PercWalletProvider extends ChangeNotifier {
  /// Disable auto-logout timers in widget/unit tests (see test setUp).
  @visibleForTesting
  static bool sessionTimeoutEnabled = true;

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
  bool _syncingWallet = false;
  bool _sessionTimedOut = false;
  Timer? _microblockCommitDebounce;
  Timer? _sessionExpiryTimer;

  bool get isReady => _ready;
  bool get isSyncingWallet => _syncingWallet;
  bool get sessionTimedOut => _sessionTimedOut;
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
  int get scenarioBlockHeight =>
      _ledger.sessionAccount?.scenarioBlockHeight ?? 0;
  int get seedAnchorBlock =>
      PercSeedBlock.fromTreasuryMinted(_ledger.cumulativeTreasuryMinted);
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
  bool get treasuryNeedsRegeneration => _ledger.treasuryNeedsRegeneration;
  Duration? get timeToNextInflation => _ledger.timeToNextInflation();
  bool get inflationReady =>
      PercInflation.isInflationReady(timeToNextInflation);
  bool get isTreasuryAccount =>
      loggedInUsername == PercChainConstants.treasuryUsername;
  bool get blockchainLaunched => _ledger.blockchainLaunched;
  bool get isTreasurySendLocked => _ledger.isTreasurySendLocked;
  bool get canSendFromSession =>
      isLoggedIn && !(isTreasuryAccount && isTreasurySendLocked);

  /// Every registered user can receive PERC (including locked treasury).
  bool get canReceiveFromSession => isLoggedIn;

  PercSideChainState get sideChain => PercSideChainState.fromLedger(_ledger);
  List<PercMicroblockLogEntry> get microblockLog =>
      List.unmodifiable(_ledger.microblockLog);

  List<String> get allRegisteredWallets {
    final list = _ledger.accounts.keys.toList()..sort();
    return list;
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
  bool get isConnectedToSeed =>
      PercLedgerHub.instance.network.isConnectedToSeed;
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
    if (_ledger.isLoggedIn) {
      if (_ledger.isWalletSessionExpired()) {
        // Local-only logout so splash boot never blocks on seed/network sync.
        await _clearExpiredSessionOnBoot();
      } else {
        _armSessionTimeout();
      }
    }
    _ready = true;
    notifyListeners();
  }

  /// Clears an expired persisted session without waiting on network I/O.
  Future<void> _clearExpiredSessionOnBoot() async {
    _cancelSessionTimeout();
    _sessionTimedOut = true;
    final username = _ledger.sessionUsername;
    _ledger.logout();
    lastReward = null;
    _clearMessages();
    await PercLedgerHub.instance.persistLocal();
    if (username != null) {
      unawaited(_finalizeSessionEndOnNetwork(username));
    }
  }

  Future<void> _finalizeSessionEndOnNetwork(String username) async {
    try {
      await PercLedgerHub.instance.onWalletSessionEnded(username);
    } catch (_) {
      // Boot must not fail if the seed is unreachable.
    }
  }

  void checkSessionTimeout() {
    if (!_ready || !isLoggedIn) return;
    if (_ledger.isWalletSessionExpired()) {
      unawaited(_expireSession());
    }
  }

  /// Resets the dormancy timer after explicit user wallet actions.
  void noteUserActivity() {
    if (!isLoggedIn) return;
    _ledger.touchWalletSessionActivity();
    _armSessionTimeout();
  }

  Future<void> setupTreasuryPassword(String password) async {
    _clearMessages();
    try {
      _ledger.setupTreasuryPassword(password);
      _ledger.login(PercChainConstants.treasuryUsername, password);
      clearSessionTimedOut();
      _armSessionTimeout();
      await PercLedgerHub.instance.onWalletSessionStarted(
        PercChainConstants.treasuryUsername,
      );
      _captureTreasuryLaunchEvent();
      statusMessage = 'Treasury secured — awaiting seed treasury sign-in to launch chain';
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
      clearSessionTimedOut();
      _armSessionTimeout();
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
      clearSessionTimedOut();
      _armSessionTimeout();
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

  Future<void> syncWalletToSeed() async {
    if (!_ready) return;
    noteUserActivity();
    _clearMessages();
    _syncingWallet = true;
    notifyListeners();
    try {
      await PercLedgerHub.instance.network.forceSyncWalletToSeed();
      _ledger.refreshPendingInboundTransfers();
      await PercLedgerHub.instance.commitAfterForceSync();

      final network = PercLedgerHub.instance.network;
      if (!network.isConnectedToSeed) {
        errorMessage =
            'Cannot reach the seed node — check your internet connection and try again';
      } else if (network.isSyncedToNetwork) {
        statusMessage =
            'Wallet synced to seed — block height $networkBlockHeight';
      } else {
        statusMessage =
            'Partial sync — local height $blockHeight, network height $networkBlockHeight';
      }
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
    } finally {
      _syncingWallet = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _cancelSessionTimeout();
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
    noteUserActivity();
    if (!isLoggedIn) {
      errorMessage =
          'Sign in to send ${PercChainConstants.currencyName}';
      notifyListeners();
      return;
    }
    if (!canSendFromSession) {
      errorMessage =
          'Manual sends from ${PercChainConstants.treasuryUsername} are disabled — treasury emission and faucet payouts continue';
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
      await PercLedgerHub.instance.network.forceSyncWalletToSeed();
      final resolved =
          await PercLedgerHub.instance.network.resolveAccountByAddress(
        normalizedAddress,
      );
      if (resolved == null) {
        errorMessage =
            'Recipient PERC address not found on the network — the owner must register and sign in once so the address is discoverable';
        notifyListeners();
        return;
      }
      final recipient = resolved.username;
      final recipientOnline =
          await PercLedgerHub.instance.network.isRecipientOnlineOnSeed(
        username: recipient,
        address: normalizedAddress,
      );
      _ledger.send(
        fromUsername: _ledger.sessionUsername!,
        toAddress: normalizedAddress,
        amount: amount,
        memo: memo,
        deliverInstantly: recipientOnline,
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
            'queued until they sign in on the network within ${_formatReceiveDelay()}, otherwise returns to your wallet';
      }
      notifyListeners();
      await _commitSendAndGossip();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    }
  }

  /// Persists a send and gossips to the seed even when the local tip lags briefly.
  Future<void> _commitSendAndGossip() async {
    try {
      await _commit();
    } on StateError catch (e) {
      if (!e.message.contains('syncing')) rethrow;
      await PercLedgerHub.instance.network.forceSyncWalletToSeed();
      _ledger.refreshPendingInboundTransfers();
      await PercLedgerHub.instance.commitAfterForceSync();
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
    noteUserActivity();
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
            'Blockchain awaiting rgsnedds sign-in on the seed treasury tab';
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

  void _armSessionTimeout() {
    _cancelSessionTimeout();
    if (!sessionTimeoutEnabled || !isLoggedIn) return;
    final remaining = _ledger.walletSessionRemaining();
    if (remaining == null || remaining <= Duration.zero) {
      unawaited(_expireSession());
      return;
    }
    _sessionExpiryTimer = Timer(remaining, () {
      unawaited(_expireSession());
    });
  }

  void _cancelSessionTimeout() {
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
  }

  Future<void> _expireSession() async {
    if (!isLoggedIn) return;
    _sessionTimedOut = true;
    await logout();
  }

  void clearSessionTimedOut() => _sessionTimedOut = false;

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

  /// Records one fair-usage microblock per app interaction (field keystrokes).
  void recordFairUsageMicroblock(
    ScenarioInput input, {
    LocaleConfig locale = LocaleConfig.defaults,
  }) {
    if (!_ready || !isBlockchainLaunched) return;
    if (isLoggedIn) noteUserActivity();
    final result = _ledger.recordMicroblock(
      input: input,
      locale: locale,
      activity: 'fair_usage',
      activityLabel: input.posedQuestion.trim().isNotEmpty
          ? input.posedQuestion.trim()
          : input.topic.trim(),
    );
    if (!result.recorded) return;
    notifyListeners();
    _microblockCommitDebounce?.cancel();
    _microblockCommitDebounce = Timer(const Duration(seconds: 2), () {
      _commit();
    });
  }

  Future<void> _commit() => PercLedgerHub.instance.commit();

  @override
  void dispose() {
    _microblockCommitDebounce?.cancel();
    _cancelSessionTimeout();
    PercLedgerHub.instance.removeListener(_onHubLedgerChanged);
    super.dispose();
  }
}