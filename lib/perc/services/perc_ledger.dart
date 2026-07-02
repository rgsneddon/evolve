import '../models/perc_account.dart';
import '../models/perc_amount.dart';
import '../models/perc_block.dart';
import '../models/perc_faucet_credit_result.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import 'perc_auth.dart';
import 'perc_faucet.dart';
import 'perc_faucet_cooldown.dart';
import 'perc_staking.dart';
import 'perc_treasury.dart';

/// Local PERC ledger — blocks advance only on scenarios and transfers.
class PercLedger {
  PercLedger({
    required this.accounts,
    required this.blocks,
    required this.lastScenarioAt,
    required this.treasuryGenesisDone,
    required this.cumulativeTreasuryMinted,
    this.sessionUsername,
    this.nextTxId = 1,
  });

  final Map<String, PercAccount> accounts;
  final List<PercBlock> blocks;
  DateTime? lastScenarioAt;
  bool treasuryGenesisDone;
  PercAmount cumulativeTreasuryMinted;
  String? sessionUsername;
  int nextTxId;

  static PercLedger empty() => PercLedger(
        accounts: {},
        blocks: [],
        lastScenarioAt: null,
        treasuryGenesisDone: false,
        cumulativeTreasuryMinted: PercAmount.zero,
      );

  PercAccount? account(String username) => accounts[username];

  bool get isLoggedIn => sessionUsername != null;

  PercAccount? get sessionAccount =>
      sessionUsername == null ? null : accounts[sessionUsername];

  PercAmount get treasuryBalance =>
      accounts[PercChainConstants.treasuryUsername]?.balance ?? PercAmount.zero;

  PercAmount get sessionBalance =>
      sessionAccount?.balance ?? PercAmount.zero;

  int get blockHeight => blocks.length;

  List<PercBlock> get chainBlocks => List.unmodifiable(blocks);

  Duration? faucetCooldownRemaining(String username, [DateTime? now]) {
    final acc = accounts[PercAuth.normalizeUsername(username)];
    if (acc == null) return null;
    return PercFaucetCooldown.remainingSince(
      acc.lastFaucetDrawAt,
      (now ?? DateTime.now()).toUtc(),
    );
  }

  double get treasuryProgress =>
      cumulativeTreasuryMinted.asPerc / PercChainConstants.maxSupply.asPerc;

  bool get treasuryCapped =>
      cumulativeTreasuryMinted >= PercChainConstants.maxSupply;

  PercAmount get treasuryRemaining =>
      PercChainConstants.maxSupply - cumulativeTreasuryMinted;

  bool treasuryNeedsPasswordSetup() {
    final t = accounts[PercChainConstants.treasuryUsername];
    return t != null && !t.passwordSet;
  }

  bool hasAccount(String username) =>
      accounts.containsKey(PercAuth.normalizeUsername(username));

  String _newTxId() => 'tx-${nextTxId++}';

  void ensureTreasuryAccount() => _ensureTreasury();

  PercAccount _ensureTreasury() {
    final key = PercChainConstants.treasuryUsername;
    if (accounts.containsKey(key)) return accounts[key]!;
    final salt = PercAuth.generateSalt();
    final a = PercAccount(
      username: key,
      passwordHash: '',
      salt: salt,
      address: PercAuth.deriveAddress(key, salt),
      passwordSet: false,
    );
    accounts[key] = a;
    return a;
  }

  void _assertValidPassword(String password) {
    final err = PercAuth.validatePassword(password);
    if (err != null) throw StateError(err);
  }

  void _assertValidUsername(String username) {
    final err = PercAuth.validateUsername(username);
    if (err != null) throw StateError(err);
  }

  PercAmount _treasuryEmissionForScenario(DateTime now) {
    if (treasuryCapped) return PercAmount.zero;
    final perSecond = PercChainConstants.treasuryEmissionPerSecond;
    if (!treasuryGenesisDone) return perSecond;
    if (lastScenarioAt == null) return PercAmount.zero;
    final elapsed = now.difference(lastScenarioAt!).inSeconds;
    if (elapsed <= 0) return PercAmount.zero;
    var emission = perSecond * elapsed;
    if (emission > treasuryRemaining) emission = treasuryRemaining;
    return emission;
  }

  void _credit(PercAccount acc, PercAmount amount) {
    acc.balance = acc.balance + amount;
  }

  void _debit(PercAccount acc, PercAmount amount) {
    if (acc.balance < amount) throw StateError('Insufficient PERC balance');
    acc.balance = acc.balance - amount;
  }

  void _applyStakingRewards(DateTime now, List<PercTransaction> blockTxs) {
    final treasury = _ensureTreasury();
    final blockIndex = blocks.length;
    final holders = <String, PercAmount>{};

    for (final entry in accounts.entries) {
      if (entry.key == PercChainConstants.treasuryUsername) continue;
      if (entry.value.balance.isPositive) {
        holders[entry.key] = entry.value.balance;
      }
    }

    for (final entry in holders.entries) {
      final reward = PercStaking.rewardForBalance(entry.value);
      if (!reward.isPositive || treasury.balance < reward) continue;

      final acc = accounts[entry.key]!;
      _debit(treasury, reward);
      _credit(acc, reward);
      acc.cumulativeStakingEarned = acc.cumulativeStakingEarned + reward;

      final tx = PercTransaction(
        id: _newTxId(),
        kind: PercTxKind.stakingReward,
        amount: reward,
        timestamp: now,
        fromUsername: PercChainConstants.treasuryUsername,
        toUsername: entry.key,
        memo: 'Cumulative staking (10% of base per PERC held)',
        blockIndex: blockIndex,
      );
      treasury.transactions.insert(0, tx);
      acc.transactions.insert(0, tx);
      blockTxs.add(tx);
    }
  }

  void _appendBlock({
    required DateTime timestamp,
    required List<PercTransaction> txs,
    required PercAmount treasuryEmitted,
    String? scenarioLabel,
    String? triggerUsername,
  }) {
    blocks.add(PercBlock(
      index: blocks.length,
      timestamp: timestamp,
      transactions: List.unmodifiable(txs),
      treasuryEmitted: treasuryEmitted,
      scenarioLabel: scenarioLabel,
      triggerUsername: triggerUsername,
    ));
  }

  void _finalizeBlock({
    required DateTime timestamp,
    required List<PercTransaction> blockTxs,
    required PercAmount treasuryEmitted,
    String? scenarioLabel,
    String? triggerUsername,
  }) {
    if (blockTxs.isEmpty) return;
    _applyStakingRewards(timestamp, blockTxs);
    _appendBlock(
      timestamp: timestamp,
      txs: blockTxs,
      treasuryEmitted: treasuryEmitted,
      scenarioLabel: scenarioLabel,
      triggerUsername: triggerUsername,
    );
  }

  void setupTreasuryPassword(String password) {
    _assertValidPassword(password);
    final treasury = _ensureTreasury();
    final salt = PercAuth.generateSalt();
    treasury
      ..salt = salt
      ..passwordHash = PercAuth.hashPassword(password, salt)
      ..passwordSet = true;
  }

  PercAccount register(String username, String password) {
    final u = PercAuth.normalizeUsername(username);
    _assertValidUsername(u);
    _assertValidPassword(password);
    if (accounts.containsKey(u)) throw StateError('Username already taken');
    final salt = PercAuth.generateSalt();
    final acc = PercAccount(
      username: u,
      passwordHash: PercAuth.hashPassword(password, salt),
      salt: salt,
      address: PercAuth.deriveAddress(u, salt),
    );
    accounts[u] = acc;
    return acc;
  }

  PercAccount login(String username, String password) {
    final u = PercAuth.normalizeUsername(username);
    final acc = accounts[u];
    if (acc == null || !acc.passwordSet) throw StateError('Unknown account');
    if (!PercAuth.verifyPassword(
      password: password,
      salt: acc.salt,
      expectedHash: acc.passwordHash,
    )) {
      throw StateError('Invalid password');
    }
    sessionUsername = u;
    return acc;
  }

  void logout() => sessionUsername = null;

  PercTransaction send({
    required String fromUsername,
    required String toUsername,
    required PercAmount amount,
    String? memo,
  }) {
    final from = PercAuth.normalizeUsername(fromUsername);
    final to = PercAuth.normalizeUsername(toUsername);
    if (from == to) throw StateError('Cannot send to yourself');
    if (!amount.isPositive) throw StateError('Amount must be positive');
    final sender = accounts[from];
    final receiver = accounts[to];
    if (sender == null || receiver == null) {
      throw StateError('Account not found');
    }
    _debit(sender, amount);
    _credit(receiver, amount);
    final now = DateTime.now().toUtc();
    final tx = PercTransaction(
      id: _newTxId(),
      kind: PercTxKind.transfer,
      amount: amount,
      timestamp: now,
      fromUsername: from,
      toUsername: to,
      memo: memo,
      blockIndex: blocks.length,
    );
    sender.transactions.insert(0, tx);
    receiver.transactions.insert(0, tx);
    _finalizeBlock(
      timestamp: now,
      blockTxs: [tx],
      treasuryEmitted: PercAmount.zero,
      triggerUsername: from,
    );
    return tx;
  }

  PercFaucetCreditResult creditScenario({
    required String username,
    required double percentChance,
    String? scenarioLabel,
  }) {
    final u = PercAuth.normalizeUsername(username);
    final user = accounts[u];
    if (user == null) {
      return const PercFaucetCreditResult(
        status: PercFaucetCreditStatus.notLoggedIn,
      );
    }

    final now = DateTime.now().toUtc();
    final cooldownLeft = PercFaucetCooldown.remainingSince(user.lastFaucetDrawAt, now);
    final treasury = _ensureTreasury();
    final emitted = _treasuryEmissionForScenario(now);
    final blockTxs = <PercTransaction>[];

    if (emitted.isPositive) {
      treasuryGenesisDone = true;
      cumulativeTreasuryMinted = cumulativeTreasuryMinted + emitted;
      _credit(treasury, emitted);
      final tx = PercTransaction(
        id: _newTxId(),
        kind: PercTxKind.treasuryEmission,
        amount: emitted,
        timestamp: now,
        toUsername: PercChainConstants.treasuryUsername,
        blockIndex: blocks.length,
      );
      treasury.transactions.insert(0, tx);
      blockTxs.add(tx);
    } else if (!treasuryGenesisDone) {
      treasuryGenesisDone = true;
    }

    final reward = PercFaucet.computeScenarioReward(percentChance: percentChance);
    PercFaucetReward? credited;

    if (cooldownLeft != null) {
      if (blockTxs.isNotEmpty) {
        _finalizeBlock(
          timestamp: now,
          blockTxs: blockTxs,
          treasuryEmitted: emitted,
          scenarioLabel: scenarioLabel,
          triggerUsername: u,
        );
        lastScenarioAt = now;
      }
      return PercFaucetCreditResult(
        status: PercFaucetCreditStatus.onCooldown,
        cooldownRemaining: cooldownLeft,
        nextBlockEstimate: cooldownLeft,
        blockIndex: blocks.isEmpty ? null : blocks.last.index,
      );
    }

    if (treasury.balance >= reward.total) {
      _debit(treasury, reward.total);
      _credit(user, reward.total);
      user.lastFaucetDrawAt = now;
      final label = scenarioLabel?.trim().isNotEmpty == true
          ? scenarioLabel!.trim()
          : 'Scenario analysis reward';
      final tx = PercTransaction(
        id: _newTxId(),
        kind: PercTxKind.scenarioReward,
        amount: reward.total,
        timestamp: now,
        fromUsername: PercChainConstants.treasuryUsername,
        toUsername: u,
        scenarioLabel: label,
        percentChance: reward.percentChance,
        blockIndex: blocks.length,
      );
      treasury.transactions.insert(0, tx);
      user.transactions.insert(0, tx);
      blockTxs.add(tx);
      credited = reward;
    }

    if (blockTxs.isNotEmpty) {
      _finalizeBlock(
        timestamp: now,
        blockTxs: blockTxs,
        treasuryEmitted: emitted,
        scenarioLabel: scenarioLabel,
        triggerUsername: u,
      );
    }

    lastScenarioAt = now;

    if (credited != null) {
      return PercFaucetCreditResult(
        status: PercFaucetCreditStatus.credited,
        reward: credited,
        blockIndex: blocks.isEmpty ? null : blocks.last.index,
      );
    }

    return PercFaucetCreditResult(
      status: PercFaucetCreditStatus.treasuryEmpty,
      blockIndex: blocks.isEmpty ? null : blocks.last.index,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'accounts': accounts.map((k, v) => MapEntry(k, v.toJson())),
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'lastScenarioAt': lastScenarioAt?.toIso8601String(),
        'treasuryGenesisDone': treasuryGenesisDone,
        'cumulativeTreasuryMinted': cumulativeTreasuryMinted.toJson(),
        'sessionUsername': sessionUsername,
        'nextTxId': nextTxId,
      };

  factory PercLedger.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('chainId')) {
      return _migrateFromChainService(json);
    }
    final version = json['version'] as int? ?? 1;
    if (version < 2) return _migrateFromV1(json);

    final accts = <String, PercAccount>{};
    final raw = json['accounts'] as Map<String, dynamic>? ?? {};
    for (final e in raw.entries) {
      accts[e.key] = PercAccount.fromJson(e.value as Map<String, dynamic>);
    }
    return PercLedger(
      accounts: accts,
      blocks: (json['blocks'] as List<dynamic>? ?? [])
          .map((e) => PercBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastScenarioAt: json['lastScenarioAt'] != null
          ? DateTime.parse(json['lastScenarioAt'] as String)
          : null,
      treasuryGenesisDone: json['treasuryGenesisDone'] as bool? ?? false,
      cumulativeTreasuryMinted: json['cumulativeTreasuryMinted'] != null
          ? PercAmount.fromJson(
              json['cumulativeTreasuryMinted'] as Map<String, dynamic>)
          : PercAmount.zero,
      sessionUsername: json['sessionUsername'] as String?,
      nextTxId: json['nextTxId'] as int? ?? 1,
    );
  }

  static PercLedger _migrateFromChainService(Map<String, dynamic> json) {
    final ledger = PercLedger.empty();
    final treasury = PercTreasury.fromJson(
      Map<String, dynamic>.from(json['treasury'] as Map? ?? {}),
    );
    final t = ledger._ensureTreasury();
    t.balance = treasury.poolBalance;
    ledger.cumulativeTreasuryMinted = treasury.cumulativeMinted;
    ledger.treasuryGenesisDone = treasury.cumulativeMinted.isPositive;
    ledger.lastScenarioAt = treasury.lastTick;

    final oldBalance = PercAmount(json['balance'] as int? ?? 0);
    if (oldBalance.isPositive) {
      final salt = PercAuth.generateSalt();
      final migrated = PercAccount(
        username: 'migrated',
        passwordHash: '',
        salt: salt,
        address: PercAuth.deriveAddress('migrated', salt),
        passwordSet: false,
        balance: oldBalance,
      );
      ledger.accounts['migrated'] = migrated;
    }
    return ledger;
  }

  static PercLedger _migrateFromV1(Map<String, dynamic> json) {
    final ledger = PercLedger.empty();
    ledger._ensureTreasury();
    ledger.treasuryGenesisDone = json['treasuryGenesisDone'] as bool? ?? false;
    if (json['lastTick'] != null) {
      ledger.lastScenarioAt = DateTime.parse(json['lastTick'] as String);
    }
    final bal = json['balance'];
    if (bal != null) {
      final amount = bal is Map
          ? PercAmount.fromJson(bal as Map<String, dynamic>)
          : PercAmount(bal as int? ?? 0);
      if (amount.isPositive) {
        ledger.accounts[PercChainConstants.treasuryUsername]!.balance = amount;
      }
    }
    return ledger;
  }
}