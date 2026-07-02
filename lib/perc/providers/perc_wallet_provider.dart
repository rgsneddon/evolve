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
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import '../services/perc_faucet.dart';
import '../services/perc_faucet_cooldown.dart';
import '../services/perc_inflation.dart';
import '../services/perc_ledger.dart';
import '../services/perc_ledger_hub.dart';
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

  /// Mesh peers excluding the signed-in user — for send picker.
  List<String> get sendablePeers {
    if (!isLoggedIn) return const [];
    final self = loggedInUsername!;
    return connectedPeerWallets.where((p) => p != self).toList();
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
    _ready = true;
    notifyListeners();
  }

  Future<void> setupTreasuryPassword(String password) async {
    _clearMessages();
    try {
      _ledger.setupTreasuryPassword(password);
      _ledger.login(PercChainConstants.treasuryUsername, password);
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
    _ledger.logout();
    lastReward = null;
    _clearMessages();
    notifyListeners();
    await _commit();
  }

  Future<void> send({
    required String toUsername,
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
    if (amount == null || !amount.isPositive) {
      errorMessage =
          'Enter a valid ${PercChainConstants.currencySymbol} amount';
      notifyListeners();
      return;
    }
    try {
      _ledger.send(
        fromUsername: _ledger.sessionUsername!,
        toUsername: toUsername,
        amount: amount,
        memo: memo,
      );
      _captureGenesisRenewalEvent();
      statusMessage = _pendingGenesisRenewalNotice
          ? 'Genesis block — treasury cycle $treasuryCycle renewed (283M ${PercChainConstants.currencySymbol} ${PercChainConstants.currencyName})'
          : 'Sent ${amount.displayFixed8} ${PercChainConstants.currencySymbol} to $toUsername';
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
  }) async {
    return creditScenario(
      outcomeScore: outcomeScore,
      memo: memo,
      analysisMode: mode,
    );
  }

  Future<PercFaucetCreditResult?> creditScenario({
    required double outcomeScore,
    String? memo,
    AnalysisMode? analysisMode,
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

  Future<void> _commit() => PercLedgerHub.instance.commit();

  @override
  void dispose() {
    PercLedgerHub.instance.removeListener(_onHubLedgerChanged);
    super.dispose();
  }
}