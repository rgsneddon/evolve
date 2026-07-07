import 'dart:async';
import 'dart:typed_data';

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

import '../../l10n/app_localizations.dart';
import '../../l10n/wallet_message_localization.dart';
import '../perc_chain_constants.dart';
import '../services/inbound_transfer_delivery.dart';
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
import '../services/perc_wallet_backup.dart';
import '../services/perc_seed_recovery.dart';
import '../services/security_recovery_service.dart';

class PercWalletProvider extends ChangeNotifier {
  /// Disable auto-logout timers in widget/unit tests (see test setUp).
  @visibleForTesting
  static bool sessionTimeoutEnabled = true;

  PercWalletProvider({
    PercWalletStore? store,
    SecurityRecoveryService? recoveryService,
  })  : _store = store ?? createPercWalletStore(),
        _recoveryService = recoveryService ?? SecurityRecoveryService.production() {
    PercLedgerHub.instance.addListener(_onHubLedgerChanged);
    PercLedgerHub.instance.network.addListener(_onNetworkActivity);
  }

  final PercWalletStore _store;
  final SecurityRecoveryService _recoveryService;
  PercLedger get _ledger => PercLedgerHub.instance.ledger;
  bool _ready = false;
  PercFaucetReward? lastReward;
  String? statusMessage;
  String? errorMessage;
  Map<String, String> statusMessageArgs = const {};
  Map<String, String> errorMessageArgs = const {};

  String? localizedStatusMessage(AppLocalizations strings) =>
      WalletMessageLocalization(strings).format(statusMessage, statusMessageArgs);

  String? localizedErrorMessage(AppLocalizations strings) =>
      WalletMessageLocalization(strings).format(errorMessage, errorMessageArgs);
  PercFaucetCreditResult? _pendingCooldownPopup;
  bool _pendingLaunchBalloon = false;
  bool _pendingGenesisRenewalNotice = false;
  bool _syncingWallet = false;
  bool _postLoginSyncing = false;
  bool _pendingSeedSetup = false;
  List<String>? _pendingRegistrationMnemonic;
  bool _sessionTimedOut = false;
  bool _extendingSessionForConnection = false;
  Timer? _microblockCommitDebounce;
  Timer? _sessionExpiryTimer;
  Timer? _ephemeralStatusTimer;

  bool get isReady => _ready;
  bool get isSyncingWallet => _syncingWallet;
  bool get isPostLoginSyncing => _postLoginSyncing;
  bool get pendingSeedSetup => _pendingSeedSetup;
  bool get isWalletConnectComplete =>
      hasAppAccess && !_postLoginSyncing && !_pendingSeedSetup;
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

  /// Treasury has no manual receive address after blockchain launch.
  bool get canReceiveFromSession =>
      isLoggedIn && !(isTreasuryAccount && isTreasurySendLocked);

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
  PercAmount get dynamicTreasuryEmissionPerMinute =>
      _ledger.dynamicTreasuryEmissionPerMinute;
  int get emissionLoadFactorPercent => _ledger.emissionLoadFactorPercent;
  int get emissionBlockTimeFactorPercent =>
      _ledger.emissionBlockTimeFactorPercent;

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
        final username = _ledger.sessionUsername;
        if (username != null) {
          // Restore seed heartbeat/receive polling for a persisted sign-in.
          unawaited(_resumeNetworkSession(username));
        }
      }
    }
    _ready = true;
    notifyListeners();
  }

  /// Re-attaches seed rendezvous for a wallet that stayed signed in locally.
  Future<void> _resumeNetworkSession(String username) async {
    _postLoginSyncing = true;
    notifyListeners();
    try {
      await PercLedgerHub.instance.onWalletSessionStarted(username);
      if (isLoggedIn && isConnectedToSeed) {
        _extendSessionForConnection();
      }
    } catch (_) {
      // Boot must not fail if the seed is unreachable.
    } finally {
      _postLoginSyncing = false;
      notifyListeners();
    }
  }

  /// Seed heartbeats and sync keep the session alive while this connection holds.
  void _onNetworkActivity() {
    if (!_ready || !isLoggedIn || !sessionTimeoutEnabled) return;
    if (isConnectedToSeed) {
      _extendSessionForConnection();
    }
  }

  bool get _sessionHeldByConnection =>
      sessionTimeoutEnabled && isLoggedIn && isConnectedToSeed;

  /// Refreshes dormancy timestamps without re-entering network listeners.
  void _extendSessionForConnection() {
    if (!isLoggedIn || _extendingSessionForConnection) return;
    _extendingSessionForConnection = true;
    try {
      _ledger.touchWalletSessionActivity();
      _cancelSessionTimeout();
      if (!sessionTimeoutEnabled) return;
      final remaining = _ledger.walletSessionRemaining();
      final delay = remaining == null || remaining <= Duration.zero
          ? PercChainConstants.walletSessionIdleTimeoutEffective
          : remaining;
      _sessionExpiryTimer = Timer(delay, () {
        unawaited(_expireSession());
      });
    } finally {
      _extendingSessionForConnection = false;
    }
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
    if (_sessionHeldByConnection) {
      _extendSessionForConnection();
      return;
    }
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
      _setStatus('wallet_status_treasury_secured');
      notifyListeners();
      await _commit();
    } catch (e) {
      _setError(WalletMessageLocalization.errorKeyFromException(e));
      notifyListeners();
    }
  }

  Future<void> register(String username, String password) async {
    _clearMessages();
    try {
      _ledger.register(username, password);
      _ledger.login(username, password);
      _pendingRegistrationMnemonic = null;
      _pendingSeedSetup = true;
      clearSessionTimedOut();
      notifyListeners();
      if (!sessionTimeoutEnabled) {
        await completeRegistrationSeedSetup(enableSeed: false);
      }
    } catch (e) {
      _pendingSeedSetup = false;
      _pendingRegistrationMnemonic = null;
      _setError(WalletMessageLocalization.errorKeyFromException(e));
      notifyListeners();
    }
  }

  /// Generates a 12-word phrase for the one-time registration offer (not yet saved).
  Future<List<String>> generateRegistrationSeed() async {
    if (!_pendingSeedSetup) {
      throw StateError('Seed setup is not pending');
    }
    final mnemonic = PercSeedRecovery.generateMnemonic();
    _pendingRegistrationMnemonic = mnemonic;
    notifyListeners();
    return mnemonic;
  }

  /// Finalizes registration after the user accepts or skips the seed offer.
  Future<void> completeRegistrationSeedSetup({required bool enableSeed}) async {
    if (!_pendingSeedSetup) return;
    _clearMessages();
    final username = _ledger.sessionUsername;
    if (username == null) {
      _pendingSeedSetup = false;
      _pendingRegistrationMnemonic = null;
      notifyListeners();
      return;
    }
    try {
      if (enableSeed) {
        final mnemonic = _pendingRegistrationMnemonic;
        if (mnemonic == null || mnemonic.isEmpty) {
          throw StateError('Generate a seed phrase before continuing');
        }
        _ledger.attachSeedRecoveryEnvelope(
          username: PercAuth.normalizeUsername(username),
          mnemonic: mnemonic,
        );
      }
      _pendingSeedSetup = false;
      _pendingRegistrationMnemonic = null;
      _armSessionTimeout();
      notifyListeners();
      await _completeWalletSessionStart(
        username,
        statusKey: enableSeed
            ? 'wallet_status_account_created_seed'
            : 'wallet_status_account_created',
      );
    } catch (e) {
      _setError(WalletMessageLocalization.errorKeyFromException(e));
      notifyListeners();
      rethrow;
    }
  }

  Uint8List exportEncryptedBackup(String passphrase) {
    if (!isLoggedIn) throw StateError('Sign in to export a backup');
    if (passphrase.length < 8) {
      throw StateError('Backup passphrase must be at least 8 characters');
    }
    return PercWalletBackup.exportEncrypted(
      ledger: _ledger.snapshotForBackup(),
      passphrase: passphrase,
    );
  }

  Future<void> restoreFromEncryptedBackup(
    Uint8List bytes,
    String passphrase,
  ) async {
    _clearMessages();
    try {
      final restored = _recoveryService.importEncryptedBackup(
        bytes: bytes,
        passphrase: passphrase,
      );
      final session = SecurityRecoveryService.resolveSessionUsername(restored);
      await PercLedgerHub.instance.restoreFromBackup(
        restored,
        sessionUsername: session,
      );
      clearSessionTimedOut();
      _armSessionTimeout();
      _setStatus('wallet_status_backup_restored');
      notifyListeners();
    } catch (e) {
      _setError(WalletMessageLocalization.errorKeyFromException(e));
      notifyListeners();
      rethrow;
    }
  }

  Future<void> recoverFromSeedPhrase(List<String> words) async {
    _clearMessages();
    try {
      final restored = await _recoveryService.recoverLedgerFromSeed(
        ledger: _ledger,
        words: words,
      );
      final session = SecurityRecoveryService.resolveSessionUsername(restored);
      await PercLedgerHub.instance.restoreFromBackup(
        restored,
        sessionUsername: session,
      );
      clearSessionTimedOut();
      _armSessionTimeout();
      _setStatus('wallet_status_seed_restored');
      notifyListeners();
    } catch (e) {
      _setError(WalletMessageLocalization.errorKeyFromException(e));
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshSeedRecoveryEnvelope(List<String> mnemonic) async {
    if (!isLoggedIn) return;
    _ledger.attachSeedRecoveryEnvelope(
      username: loggedInUsername!,
      mnemonic: mnemonic,
    );
    await PercLedgerHub.instance.persistLocal();
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    _clearMessages();
    try {
      _ledger.login(username, password);
      clearSessionTimedOut();
      _armSessionTimeout();
      notifyListeners();
      await _completeWalletSessionStart(
        username,
        statusKey: 'wallet_status_signed_in',
        statusArgs: {'user': _ledger.sessionUsername ?? ''},
        captureLaunch: true,
      );
    } catch (e) {
      _postLoginSyncing = false;
      _setError(WalletMessageLocalization.errorKeyFromException(e));
      notifyListeners();
    }
  }

  Future<void> _completeWalletSessionStart(
    String username, {
    required String statusKey,
    Map<String, String> statusArgs = const {},
    bool captureLaunch = false,
  }) async {
    _postLoginSyncing = true;
    notifyListeners();
    try {
      await PercLedgerHub.instance.onWalletSessionStarted(username);
      if (captureLaunch) _captureTreasuryLaunchEvent();
      _setStatus(statusKey, statusArgs);
      await PercLedgerHub.instance.persistLocal();
    } finally {
      _postLoginSyncing = false;
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
        _setError('wallet_sync_seed_offline');
      } else if (network.isSyncedToNetwork) {
        _setStatus(
          'wallet_sync_success',
          {'height': '$networkBlockHeight'},
        );
      } else {
        _setStatus(
          'wallet_sync_partial',
          {
            'local': '$blockHeight',
            'network': '$networkBlockHeight',
          },
        );
      }
    } catch (e) {
      _setError(WalletMessageLocalization.errorKeyFromException(e));
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
      _setError(
        'wallet_err_sign_in_to_send',
        {'name': PercChainConstants.currencyName},
      );
      notifyListeners();
      return;
    }
    if (!canSendFromSession) {
      _setError('wallet_treasury_send_locked');
      notifyListeners();
      return;
    }
    final amount = PercAmount.tryParseDisplay(amountText);
    if (amount == null) {
      _setError(
        'wallet_err_invalid_amount',
        {'symbol': PercChainConstants.currencySymbol},
      );
      notifyListeners();
      return;
    }
    if (!amount.isAtLeastSmallestUnit) {
      _setError(
        'wallet_err_minimum_send',
        {
          'min': PercChainConstants.centValueInPerc,
          'symbol': PercChainConstants.currencySymbol,
        },
      );
      notifyListeners();
      return;
    }
    final fee = PercChainConstants.sendTransactionFee;
    final totalDebit = amount + fee;
    if (balance < totalDebit) {
      _setError(
        'wallet_err_insufficient_balance',
        {
          'total': totalDebit.displayFixed8,
          'symbol': PercChainConstants.currencySymbol,
          'amount': amount.displayFixed8,
          'fee': fee.displayFixed8,
        },
      );
      notifyListeners();
      return;
    }
    final addrErr = PercAuth.validateAddress(toAddress);
    if (addrErr != null) {
      _setError(WalletMessageLocalization.addressErrorKey(addrErr) ?? 'wallet_err_address_invalid');
      notifyListeners();
      return;
    }
    final normalizedAddress = PercAuth.normalizeAddress(toAddress);
    try {
      await PercLedgerHub.instance.network.quickSyncToNetworkHeight();
      final resolved =
          await PercLedgerHub.instance.network.resolveAccountByAddress(
        normalizedAddress,
      );
      if (resolved == null) {
        final treasury = _ledger.account(PercChainConstants.treasuryUsername);
        if (treasury != null &&
            treasury.address == normalizedAddress &&
            _ledger.isManualReceiveBlocked(PercChainConstants.treasuryUsername)) {
          _setError('wallet_err_treasury_no_manual_funding');
        } else {
          _setError('wallet_err_recipient_not_found');
        }
        notifyListeners();
        return;
      }
      final recipient = resolved.username;
      if (_ledger.isManualReceiveBlocked(recipient)) {
        _setError('wallet_err_treasury_no_manual_funding');
        notifyListeners();
        return;
      }
      final recipientLocal = _ledger.account(recipient);
      final deliveryPlan = InboundTransferDeliveryPlan.planSend(
        isLocalSettleableRecipient:
            recipientLocal != null && recipientLocal.passwordSet,
      );
      final tx = _ledger.send(
        fromUsername: _ledger.sessionUsername!,
        toAddress: normalizedAddress,
        amount: amount,
        memo: memo,
        deliverInstantly: false,
        seedConfirmationBlockHeight:
            PercLedgerHub.instance.network.networkBlockHeight,
      );
      _captureGenesisRenewalEvent();
      final dest = PercBeamPrivacy.shieldAddress(normalizedAddress);
      if (_pendingGenesisRenewalNotice) {
        _setGenesisRenewalStatus();
      } else {
        final statusKey = tx.confirmations > 0
            ? deliveryPlan.walletStatusKey
            : deliveryPlan.addToPendingQueue
                ? deliveryPlan.walletStatusKey
                : InboundTransferDeliveryPlan.relay.walletStatusKey;
        final statusArgs = {
          'amount': amount.displayFixed8,
          'symbol': PercChainConstants.currencySymbol,
          'dest': dest,
          'fee': fee.displayFixed8,
          if (deliveryPlan.addToPendingQueue)
            'delayKey': _inboundRevertWindowKey(),
        };
        _setEphemeralStatus(statusKey, statusArgs);
      }
      notifyListeners();
      await _commitSendAndGossip(
        recipientUsername: recipient,
        recipientAddress: normalizedAddress,
      );
    } catch (e) {
      _setError(WalletMessageLocalization.errorKeyFromException(e));
      notifyListeners();
    }
  }

  /// Pull inbound PERC immediately (send screen, app resume, wallet tab focus).
  Future<void> refreshInboundNow() async {
    if (!_ready || !isLoggedIn) return;
    await PercLedgerHub.instance.network.pollForInboundTransfers();
    notifyListeners();
  }

  /// Persists a send and gossips to the seed even when the local tip lags briefly.
  Future<void> _commitSendAndGossip({
    String? recipientUsername,
    String? recipientAddress,
  }) async {
    try {
      await PercLedgerHub.instance.commitAfterSend(
        relayRecipientUsername: recipientUsername,
        relayRecipientAddress: recipientAddress,
      );
    } on StateError catch (e) {
      if (!e.message.contains('syncing')) rethrow;
      await PercLedgerHub.instance.network.forceSyncWalletToSeed();
      _ledger.refreshPendingInboundTransfers();
      await PercLedgerHub.instance.commitAfterForceSync();
      await PercLedgerHub.instance.network.pushLedgerToRecipient(
        username: recipientUsername,
        address: recipientAddress,
        ledger: _ledger,
      );
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
      final session = _ledger.sessionUsername!;
      await PercLedgerHub.instance.network.prefetchSenderPeersForPending(
        session,
      );
      final label = memo ??
          (analysisMode == AnalysisMode.cohesionScore
              ? 'wallet_faucet_label_scs'
              : 'wallet_faucet_label_percent');
      final result = _ledger.creditScenario(
        username: session,
        percentChance: score,
        scenarioLabel: label,
        continuumScs: continuumScs ?? score,
        vortexScs: vortexScs,
        shearScs: shearScs,
        resistanceScs: resistanceScs,
        flowScs: flowScs,
        senderPeerResolver:
            PercLedgerHub.instance.network.senderPeerResolver,
      );

      _captureGenesisRenewalEvent();

      if (result.showCooldownPopup) {
        _pendingCooldownPopup = result;
        if (_pendingGenesisRenewalNotice) {
          _setGenesisRenewalStatus();
        } else {
          _setStatus(null);
        }
        notifyListeners();
        await _commitAfterScenario();
        return result;
      }

      if (result.status == PercFaucetCreditStatus.credited &&
          result.reward != null) {
        lastReward = result.reward;
        if (_pendingGenesisRenewalNotice) {
          _setGenesisRenewalStatus();
        } else {
          _setStatus(
            'wallet_status_faucet_credited',
            {
              'amount': result.reward!.total.displayFixed8,
              'symbol': PercChainConstants.currencySymbol,
            },
          );
        }
        notifyListeners();
        await _commitAfterScenario();
        return result;
      }

      if (result.status == PercFaucetCreditStatus.blockchainNotLaunched) {
        _setStatus('wallet_blockchain_awaiting_launch');
      } else if (result.status == PercFaucetCreditStatus.treasuryEmpty) {
        if (_pendingGenesisRenewalNotice) {
          _setGenesisRenewalStatus();
        } else {
          _setStatus('wallet_status_treasury_empty');
        }
      }
      notifyListeners();
      await _commitAfterScenario();
      return result;
    } catch (e) {
      _setStatus('wallet_status_treasury_cap');
      notifyListeners();
      return null;
    }
  }

  void _armSessionTimeout() {
    _cancelSessionTimeout();
    if (!sessionTimeoutEnabled || !isLoggedIn) return;
    if (_sessionHeldByConnection) {
      _extendSessionForConnection();
      return;
    }
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
    if (_sessionHeldByConnection) {
      _extendSessionForConnection();
      return;
    }
    _sessionTimedOut = true;
    await logout();
  }

  void clearSessionTimedOut() => _sessionTimedOut = false;

  void _setStatus(String? key, [Map<String, String> args = const {}]) {
    _ephemeralStatusTimer?.cancel();
    _ephemeralStatusTimer = null;
    statusMessage = key;
    statusMessageArgs = args;
    if (key != null) errorMessage = null;
  }

  void _setEphemeralStatus(String key, [Map<String, String> args = const {}]) {
    _setStatus(key, args);
    _ephemeralStatusTimer?.cancel();
    _ephemeralStatusTimer = Timer(const Duration(seconds: 15), () {
      if (statusMessage == key) {
        statusMessage = null;
        statusMessageArgs = const {};
        notifyListeners();
      }
    });
  }

  void _setError(String key, [Map<String, String> args = const {}]) {
    errorMessage = key;
    errorMessageArgs = args;
    statusMessage = null;
  }

  void _setGenesisRenewalStatus() {
    _setStatus(
      'wallet_status_genesis_renewal',
      {
        'cycle': '$treasuryCycle',
        'symbol': PercChainConstants.currencySymbol,
        'name': PercChainConstants.currencyName,
      },
    );
  }

  String _inboundRevertWindowKey() {
    final delay = PercChainConstants.walletInboundRevertWindow;
    if (delay.inDays >= 1) return 'wallet_inbound_revert_days';
    if (delay.inHours >= 1) return 'wallet_inbound_revert_hours';
    return 'wallet_inbound_revert_seconds';
  }

  void _clearMessages() {
    statusMessage = null;
    errorMessage = null;
    statusMessageArgs = const {};
    errorMessageArgs = const {};
  }

  /// Clears a login credential warning after the user dismisses it in the UI.
  void clearCredentialError() {
    if (!WalletMessageLocalization.isCredentialError(errorMessage)) return;
    _clearMessages();
    notifyListeners();
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

  Future<void> _commitAfterScenario() async {
    await PercLedgerHub.instance.commitAfterScenario();
  }

  @override
  void dispose() {
    _microblockCommitDebounce?.cancel();
    _ephemeralStatusTimer?.cancel();
    _cancelSessionTimeout();
    PercLedgerHub.instance.removeListener(_onHubLedgerChanged);
    PercLedgerHub.instance.network.removeListener(_onNetworkActivity);
    super.dispose();
  }
}