import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../models/perc_account.dart';
import '../models/perc_amount.dart';
import '../models/perc_block.dart';
import '../models/perc_faucet_credit_result.dart';
import '../models/perc_microblock_record_result.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import 'perc_auth.dart';
import 'perc_chronoflux_micro_verifier.dart';
import 'perc_faucet.dart';
import 'perc_faucet_cooldown.dart';
import 'perc_inflation.dart';
import 'perc_staking.dart';
import 'perc_treasury.dart';

/// Local Perccent ledger — blocks advance on scenarios, transfers, and Chronoflux microblock seals.
class PercLedger {
  PercLedger({
    required this.accounts,
    required this.blocks,
    required this.lastScenarioAt,
    required this.treasuryGenesisDone,
    required this.cumulativeTreasuryMinted,
    this.treasuryCycle = 1,
    this.blockchainLaunched = false,
    this.sessionUsername,
    this.nextTxId = 1,
    this.microblockCount = 0,
    this.totalMicroblocks = 0,
    this.lastChronofluxFingerprint,
    PercChronofluxMicroVerifier? microVerifier,
  }) : _microVerifier = microVerifier ?? const PercChronofluxMicroVerifier();

  final Map<String, PercAccount> accounts;
  final List<PercBlock> blocks;
  DateTime? lastScenarioAt;
  bool treasuryGenesisDone;
  PercAmount cumulativeTreasuryMinted;
  int treasuryCycle;
  bool blockchainLaunched;
  String? sessionUsername;
  int nextTxId;
  int microblockCount;
  int totalMicroblocks;
  String? lastChronofluxFingerprint;
  final PercChronofluxMicroVerifier _microVerifier;
  bool _blockchainLaunchEventPending = false;
  bool _genesisRenewalEventPending = false;

  int get microblocksPerBlock =>
      PercChainConstants.microblocksPerBlockOverride ??
      PercChainConstants.microblocksPerBlock;

  double get microblockProgress =>
      microblocksPerBlock > 0 ? microblockCount / microblocksPerBlock : 0;

  static PercLedger empty() => PercLedger(
        accounts: {},
        blocks: [],
        lastScenarioAt: null,
        treasuryGenesisDone: false,
        cumulativeTreasuryMinted: PercAmount.zero,
        treasuryCycle: 1,
        blockchainLaunched: false,
      );

  bool get isBlockchainLaunched => blockchainLaunched;

  bool consumeBlockchainLaunchEvent() {
    if (!_blockchainLaunchEventPending) return false;
    _blockchainLaunchEventPending = false;
    return true;
  }

  bool consumeGenesisRenewalEvent() {
    if (!_genesisRenewalEventPending) return false;
    _genesisRenewalEventPending = false;
    return true;
  }

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

  DateTime? get lastInflationEpoch =>
      PercInflation.lastInflationEpoch(blocks);

  bool get treasuryPoolCritical =>
      PercInflation.isPoolCritical(treasuryBalance);

  bool get isTreasurySendLocked => blockchainLaunched;

  bool get isTreasuryAtReserve =>
      treasuryBalance.microUnits ==
      PercChainConstants.minimumTreasuryReserve.microUnits;

  Duration? timeToNextInflation([DateTime? now]) =>
      PercInflation.timeToNextInflation(
        lastInflationEpoch: lastInflationEpoch,
        blockchainLaunched: blockchainLaunched,
        treasuryCapped: treasuryCapped,
        treasuryPool: treasuryBalance,
        now: (now ?? DateTime.now()).toUtc(),
      );

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

  bool _needsTreasuryPoolRenewal() =>
      treasuryCapped || isTreasuryAtReserve;

  List<PercTransaction> _renewTreasuryPoolIfNeeded(DateTime now) {
    if (!_needsTreasuryPoolRenewal()) return [];

    treasuryCycle++;
    cumulativeTreasuryMinted = PercAmount.zero;
    treasuryGenesisDone = false;
    _genesisRenewalEventPending = true;

    final treasury = _ensureTreasury();
    _credit(treasury, PercChainConstants.maxSupply);

    return [
      PercTransaction(
        id: _newTxId(),
        kind: PercTxKind.genesisRenewal,
        amount: PercChainConstants.maxSupply,
        timestamp: now,
        toUsername: PercChainConstants.treasuryUsername,
        memo:
            'Treasury pool renewal — cycle $treasuryCycle (${PercChainConstants.maxSupply.display} ${PercChainConstants.currencySymbol} minted to ${PercChainConstants.treasuryUsername})',
        blockIndex: blocks.length,
        confirmations: PercChainConstants.confirmationsRequired,
      ),
    ];
  }

  int get _txConfirmations => PercChainConstants.confirmationsRequired;

  void _assertTreasuryCanSend(String from) {
    if (from == PercChainConstants.treasuryUsername && isTreasurySendLocked) {
      throw StateError(
        'Treasury account locked — ${PercChainConstants.treasuryUsername} cannot send manually after blockchain launch',
      );
    }
  }

  bool _treasuryCanDebit(PercAmount amount) {
    final treasury = _ensureTreasury();
    final after = treasury.balance - amount;
    return after.microUnits >=
        PercChainConstants.minimumTreasuryReserve.microUnits;
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
    if (acc.balance < amount) {
      throw StateError(
        'Insufficient ${PercChainConstants.currencyName} balance',
      );
    }
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
      if (!reward.isPositive || !_treasuryCanDebit(reward)) continue;

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
        memo:
            'Cumulative staking (${PercStaking.rewardPerBlock.centDisplay} per block)',
        blockIndex: blockIndex,
        confirmations: _txConfirmations,
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
    bool isGenesisRenewal = false,
    bool microblockSeal = false,
    String? chronofluxFingerprint,
    int? microblocksSealed,
  }) {
    blocks.add(PercBlock(
      index: blocks.length,
      timestamp: timestamp,
      transactions: List.unmodifiable(txs),
      treasuryEmitted: treasuryEmitted,
      scenarioLabel: scenarioLabel,
      triggerUsername: triggerUsername,
      treasuryCycle: treasuryCycle,
      isGenesisRenewal: isGenesisRenewal,
      microblockSeal: microblockSeal,
      chronofluxFingerprint: chronofluxFingerprint,
      microblocksSealed: microblocksSealed,
    ));
  }

  void _finalizeBlock({
    required DateTime timestamp,
    required List<PercTransaction> blockTxs,
    required PercAmount treasuryEmitted,
    String? scenarioLabel,
    String? triggerUsername,
    bool isGenesisRenewal = false,
    bool microblockSeal = false,
    String? chronofluxFingerprint,
    int? microblocksSealed,
  }) {
    if (blockTxs.isEmpty) return;
    _applyStakingRewards(timestamp, blockTxs);
    _appendBlock(
      timestamp: timestamp,
      txs: blockTxs,
      treasuryEmitted: treasuryEmitted,
      scenarioLabel: scenarioLabel,
      triggerUsername: triggerUsername,
      isGenesisRenewal: isGenesisRenewal,
      microblockSeal: microblockSeal,
      chronofluxFingerprint: chronofluxFingerprint,
      microblocksSealed: microblocksSealed,
    );
    microblockCount = 0;
  }

  List<PercTransaction> _treasuryEmissionTxs(DateTime now) {
    if (treasuryCapped) return [];
    final perSecond = PercChainConstants.treasuryEmissionPerSecond;
    if (!treasuryGenesisDone) {
      treasuryGenesisDone = true;
      cumulativeTreasuryMinted = cumulativeTreasuryMinted + perSecond;
      final treasury = _ensureTreasury();
      _credit(treasury, perSecond);
      return [
        PercTransaction(
          id: _newTxId(),
          kind: PercTxKind.treasuryEmission,
          amount: perSecond,
          timestamp: now,
          toUsername: PercChainConstants.treasuryUsername,
          blockIndex: blocks.length,
          confirmations: _txConfirmations,
        ),
      ];
    }
    if (lastScenarioAt == null) return [];
    final elapsed = now.difference(lastScenarioAt!).inSeconds;
    if (elapsed <= 0) return [];
    var emission = perSecond * elapsed;
    if (emission > treasuryRemaining) emission = treasuryRemaining;
    if (!emission.isPositive) return [];

    cumulativeTreasuryMinted = cumulativeTreasuryMinted + emission;
    final treasury = _ensureTreasury();
    _credit(treasury, emission);
    final tx = PercTransaction(
      id: _newTxId(),
      kind: PercTxKind.treasuryEmission,
      amount: emission,
      timestamp: now,
      toUsername: PercChainConstants.treasuryUsername,
      blockIndex: blocks.length,
      confirmations: _txConfirmations,
    );
    treasury.transactions.insert(0, tx);
    return [tx];
  }

  /// Each keystroke verifies the Chronoflux continuum and advances one microblock.
  PercMicroblockRecordResult recordMicroblock({
    required ScenarioInput input,
    LocaleConfig locale = LocaleConfig.defaults,
    DateTime? now,
  }) {
    if (!blockchainLaunched) return PercMicroblockRecordResult.skipped;

    final verification = _microVerifier.verify(input, locale: locale);
    if (!verification.selfConsistent) return PercMicroblockRecordResult.skipped;

    microblockCount++;
    totalMicroblocks++;
    lastChronofluxFingerprint = verification.fingerprint;

    if (microblockCount < microblocksPerBlock) {
      return PercMicroblockRecordResult(
        recorded: true,
        microblockCount: microblockCount,
        selfConsistent: true,
      );
    }

    final sealedAt = (now ?? DateTime.now()).toUtc();
    final renewalTxs = _renewTreasuryPoolIfNeeded(sealedAt);
    final blockTxs = <PercTransaction>[...renewalTxs, ..._treasuryEmissionTxs(sealedAt)];
    final emitted = blockTxs
        .where((t) => t.kind == PercTxKind.treasuryEmission)
        .fold<PercAmount>(PercAmount.zero, (a, t) => a + t.amount);

    final sealedCount = microblocksPerBlock;
    blockTxs.add(
      PercTransaction(
        id: _newTxId(),
        kind: PercTxKind.chronofluxMicroblock,
        amount: PercAmount.zero,
        timestamp: sealedAt,
        memo:
            'Chronoflux microblock seal — $sealedCount microblocks (continuum ${verification.continuumPercent.toStringAsFixed(2)}%)',
        blockIndex: blocks.length,
        confirmations: _txConfirmations,
        chronofluxFingerprint: verification.fingerprint,
        microblockIndex: totalMicroblocks,
      ),
    );

    _finalizeBlock(
      timestamp: sealedAt,
      blockTxs: blockTxs,
      treasuryEmitted: emitted,
      scenarioLabel: 'Chronoflux microblock seal',
      triggerUsername: sessionUsername,
      isGenesisRenewal: renewalTxs.isNotEmpty,
      microblockSeal: true,
      chronofluxFingerprint: verification.fingerprint,
      microblocksSealed: sealedCount,
    );
    lastScenarioAt = sealedAt;

    return PercMicroblockRecordResult(
      recorded: true,
      blockSealed: true,
      microblockCount: 0,
      selfConsistent: true,
      blockIndex: blocks.last.index,
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

  void _launchBlockchainIfTreasurerFirstLogin(String username) {
    if (username != PercChainConstants.treasuryUsername) return;
    if (blockchainLaunched) return;
    blockchainLaunched = true;
    _blockchainLaunchEventPending = true;
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
    _launchBlockchainIfTreasurerFirstLogin(u);
    return acc;
  }

  void logout() => sessionUsername = null;

  PercTransaction send({
    required String fromUsername,
    required String toUsername,
    required PercAmount amount,
    String? memo,
  }) {
    if (!blockchainLaunched) {
      throw StateError(
        'Blockchain not launched — treasurer rgsneddon must sign in first',
      );
    }
    final from = PercAuth.normalizeUsername(fromUsername);
    final to = PercAuth.normalizeUsername(toUsername);
    if (from == to) throw StateError('Cannot send to yourself');
    if (!amount.isPositive) throw StateError('Amount must be positive');
    final sender = accounts[from];
    final receiver = accounts[to];
    if (sender == null || receiver == null) {
      throw StateError('Account not found');
    }
    _assertTreasuryCanSend(from);
    _debit(sender, amount);
    _credit(receiver, amount);
    final now = DateTime.now().toUtc();
    final renewalTxs = _renewTreasuryPoolIfNeeded(now);
    final tx = PercTransaction(
      id: _newTxId(),
      kind: PercTxKind.transfer,
      amount: amount,
      timestamp: now,
      fromUsername: from,
      toUsername: to,
      memo: memo,
      blockIndex: blocks.length,
      confirmations: _txConfirmations,
    );
    sender.transactions.insert(0, tx);
    receiver.transactions.insert(0, tx);
    final blockTxs = [...renewalTxs, tx];
    _finalizeBlock(
      timestamp: now,
      blockTxs: blockTxs,
      treasuryEmitted: PercAmount.zero,
      triggerUsername: from,
      isGenesisRenewal: renewalTxs.isNotEmpty,
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

    if (!blockchainLaunched) {
      return const PercFaucetCreditResult(
        status: PercFaucetCreditStatus.blockchainNotLaunched,
      );
    }

    final now = DateTime.now().toUtc();
    final cooldownLeft = PercFaucetCooldown.remainingSince(user.lastFaucetDrawAt, now);
    final treasury = _ensureTreasury();
    final renewalTxs = _renewTreasuryPoolIfNeeded(now);
    final isGenesisRenewal = renewalTxs.isNotEmpty;
    final blockTxs = <PercTransaction>[...renewalTxs];
    final emitted = _treasuryEmissionForScenario(now);

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
        confirmations: _txConfirmations,
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
          isGenesisRenewal: isGenesisRenewal,
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

    if (_treasuryCanDebit(reward.total)) {
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
        confirmations: _txConfirmations,
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
        isGenesisRenewal: isGenesisRenewal,
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
        'version': 4,
        'accounts': accounts.map((k, v) => MapEntry(k, v.toJson())),
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'lastScenarioAt': lastScenarioAt?.toIso8601String(),
        'treasuryGenesisDone': treasuryGenesisDone,
        'cumulativeTreasuryMinted': cumulativeTreasuryMinted.toJson(),
        'treasuryCycle': treasuryCycle,
        'blockchainLaunched': blockchainLaunched,
        'sessionUsername': sessionUsername,
        'nextTxId': nextTxId,
        'microblockCount': microblockCount,
        'totalMicroblocks': totalMicroblocks,
        if (lastChronofluxFingerprint != null)
          'lastChronofluxFingerprint': lastChronofluxFingerprint,
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
    final blocks = (json['blocks'] as List<dynamic>? ?? [])
        .map((e) => PercBlock.fromJson(e as Map<String, dynamic>))
        .toList();
    final treasuryGenesisDone = json['treasuryGenesisDone'] as bool? ?? false;
    return PercLedger(
      accounts: accts,
      blocks: blocks,
      lastScenarioAt: json['lastScenarioAt'] != null
          ? DateTime.parse(json['lastScenarioAt'] as String)
          : null,
      treasuryGenesisDone: treasuryGenesisDone,
      cumulativeTreasuryMinted: json['cumulativeTreasuryMinted'] != null
          ? PercAmount.fromJson(
              json['cumulativeTreasuryMinted'] as Map<String, dynamic>)
          : PercAmount.zero,
      treasuryCycle: json['treasuryCycle'] as int? ?? 1,
      blockchainLaunched: json['blockchainLaunched'] as bool? ??
          (blocks.isNotEmpty || treasuryGenesisDone),
      sessionUsername: json['sessionUsername'] as String?,
      nextTxId: json['nextTxId'] as int? ?? 1,
      microblockCount: json['microblockCount'] as int? ?? 0,
      totalMicroblocks: json['totalMicroblocks'] as int? ?? 0,
      lastChronofluxFingerprint: json['lastChronofluxFingerprint'] as String?,
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
    ledger.blockchainLaunched = treasury.cumulativeMinted.isPositive;
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
    ledger.blockchainLaunched = ledger.treasuryGenesisDone;
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