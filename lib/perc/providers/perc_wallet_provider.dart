import 'package:flutter/foundation.dart';

import '../models/perc_amount.dart';
import '../models/perc_block.dart';
import '../models/perc_faucet_credit_result.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import '../services/perc_faucet.dart';
import '../services/perc_faucet_cooldown.dart';
import '../services/perc_inflation.dart';
import '../services/perc_ledger.dart';
import '../services/perc_wallet_store.dart';
import '../services/perc_wallet_store_factory.dart';

class PercWalletProvider extends ChangeNotifier {
  PercWalletProvider({PercWalletStore? store})
      : _store = store ?? createPercWalletStore();

  final PercWalletStore _store;
  PercLedger _ledger = PercLedger.empty();
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

  /// User may use Evolve only after register/login generates a PERC address.
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
    final loaded = await _store.load();
    _ledger = loaded ?? PercLedger.empty();
    _ledger.ensureTreasuryAccount();
    await _persist();
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
      await _persist();
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
      await _persist();
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
      await _persist();
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
    await _persist();
  }

  Future<void> send({
    required String toUsername,
    required String amountText,
    String? memo,
  }) async {
    _clearMessages();
    if (!isLoggedIn) {
      errorMessage = 'Sign in to send PERC';
      notifyListeners();
      return;
    }
    final amount = PercAmount.tryParseDisplay(amountText);
    if (amount == null || !amount.isPositive) {
      errorMessage = 'Enter a valid PERC amount';
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
          ? 'Genesis block — treasury cycle $treasuryCycle renewed (286M PERC)'
          : 'Sent ${amount.displayFixed8} ${PercChainConstants.currencySymbol} to $toUsername';
      notifyListeners();
      await _persist();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    }
  }

  Future<PercFaucetCreditResult?> creditScenario({
    required double percentChance,
    String? memo,
  }) async {
    if (!_ready || !isLoggedIn) return null;
    _clearMessages();
    try {
      final result = _ledger.creditScenario(
        username: _ledger.sessionUsername!,
        percentChance: percentChance,
        scenarioLabel: memo,
      );

      _captureGenesisRenewalEvent();

      if (result.showCooldownPopup) {
        _pendingCooldownPopup = result;
        statusMessage = _pendingGenesisRenewalNotice
            ? 'Genesis block — treasury cycle $treasuryCycle renewed (286M PERC)'
            : null;
        notifyListeners();
        await _persist();
        return result;
      }

      if (result.status == PercFaucetCreditStatus.credited &&
          result.reward != null) {
        lastReward = result.reward;
        statusMessage = _pendingGenesisRenewalNotice
            ? 'Genesis block — treasury cycle $treasuryCycle renewed (286M PERC)'
            : '+${result.reward!.total.displayFixed8} ${PercChainConstants.currencySymbol}';
        notifyListeners();
        await _persist();
        return result;
      }

      if (result.status == PercFaucetCreditStatus.blockchainNotLaunched) {
        statusMessage =
            'Blockchain awaiting treasurer rgsneddon first sign-in';
      } else if (result.status == PercFaucetCreditStatus.treasuryEmpty) {
        statusMessage = _pendingGenesisRenewalNotice
            ? 'Genesis block — treasury cycle $treasuryCycle renewed (286M PERC)'
            : 'Treasury empty — run another scenario later';
      }
      notifyListeners();
      await _persist();
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

  Future<void> _persist() => _store.save(_ledger);
}