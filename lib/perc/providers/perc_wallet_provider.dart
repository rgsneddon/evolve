import 'package:flutter/foundation.dart';

import '../models/perc_amount.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import '../services/perc_faucet.dart';
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

  bool get isReady => _ready;
  bool get isLoggedIn => _ledger.isLoggedIn;
  String? get loggedInUsername => _ledger.sessionUsername;
  bool get needsTreasuryPassword => _ledger.treasuryNeedsPasswordSetup();

  PercAmount get balance => _ledger.sessionBalance;
  String get address => _ledger.sessionAccount?.address ?? '';
  List<PercTransaction> get transactions =>
      List.unmodifiable(_ledger.sessionAccount?.transactions ?? const []);
  int get blockHeight => _ledger.blockHeight;
  double get treasuryProgress => _ledger.treasuryProgress;
  PercAmount get treasuryMinted => _ledger.cumulativeTreasuryMinted;
  PercAmount get treasuryRemaining => _ledger.treasuryRemaining;
  PercAmount get treasuryPool => _ledger.treasuryBalance;
  bool get treasuryCapped => _ledger.treasuryCapped;
  bool get isTreasuryAccount =>
      loggedInUsername == PercChainConstants.treasuryUsername;

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
      statusMessage = 'Treasury secured';
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
      statusMessage =
          'Sent ${amount.displayFixed8} ${PercChainConstants.currencySymbol} to $toUsername';
      notifyListeners();
      await _persist();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    }
  }

  Future<PercFaucetReward?> creditScenario({
    required double percentChance,
    String? memo,
  }) async {
    if (!_ready || !isLoggedIn) return null;
    _clearMessages();
    try {
      final reward = _ledger.creditScenario(
        username: _ledger.sessionUsername!,
        percentChance: percentChance,
        scenarioLabel: memo,
      );
      if (reward == null) {
        statusMessage = 'Treasury empty — run another scenario later';
        notifyListeners();
        return null;
      }
      lastReward = reward;
      statusMessage =
          '+${reward.total.displayFixed8} ${PercChainConstants.currencySymbol}';
      notifyListeners();
      await _persist();
      return reward;
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