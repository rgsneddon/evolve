import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../models/perc_account.dart';
import '../models/perc_amount.dart';
import '../models/perc_block.dart';
import '../models/perc_faucet_credit_result.dart';
import '../models/perc_evolution_step.dart';
import '../models/perc_microblock_log_entry.dart';
import '../models/perc_microblock_record_result.dart';
import '../perc_app_version.dart';
import '../models/perc_transaction.dart';
import '../models/perc_pending_inbound_transfer.dart';
import '../models/perc_peer_node.dart';
import '../models/ward_proposal.dart';
import 'ward_voting.dart';
import '../perc_chain_constants.dart';
import 'perc_account_privacy.dart';
import 'perc_auth.dart';
import 'perc_chronoflux_micro_verifier.dart';
import 'perc_dynamic_emission.dart';
import 'perc_block_timing.dart';
import 'perc_chain_tip.dart';
import 'perc_network_protocol.dart';
import 'perc_wallet_mesh.dart';
import 'perc_faucet.dart';
import 'perc_faucet_cooldown.dart';
import 'perc_inflation.dart';
import 'perc_staking.dart';
import 'perc_treasury.dart';
import 'perc_transfer_relay_ack.dart';
import 'perc_settlement_witness.dart';

/// Resolves a live sender ledger for cross-device scenario attestation.
typedef PercSenderPeerResolver = PercLedger? Function(String fromUsername);

/// Local Perccent ledger — blocks advance on scenarios, transfers, and Chronoflux microblock seals.
class PercLedger {
  /// Pre-rename treasury usernames merged into [PercChainConstants.treasuryUsername].
  static const legacyTreasuryUsernames = ['rgsneddon'];
  PercLedger({
    required this.accounts,
    required this.blocks,
    required this.lastScenarioAt,
    required this.treasuryGenesisDone,
    required this.cumulativeTreasuryMinted,
    PercAmount? cumulativeBurnedPerc,
    this.treasuryCycle = 1,
    this.blockchainLaunched = false,
    this.sessionUsername,
    this.sessionStartedAt,
    this.sessionLastActivityAt,
    this.nextTxId = 1,
    this.microblockCount = 0,
    this.totalMicroblocks = 0,
    this.lastChronofluxFingerprint,
    Map<String, List<String>>? walletPeers,
    Map<String, PercPeerNode>? networkNodes,
    this.evolutionaryChainId = '',
    this.chronofluxPrincipiaId = '',
    this.mainChainId = '',
    this.sideChainId = '',
    this.connectedAppVersion = '',
    List<String>? evolvedAppVersions,
    List<PercEvolutionStep>? evolutionSteps,
    this.evolutionEpoch = 1,
    this.networkGenesisRevision = 1,
    List<WardProposal>? wardProposals,
    List<WardBallot>? wardBallots,
    this.nextWardProposalId = 1,
    List<PercPendingInboundTransfer>? pendingInboundTransfers,
    List<PercSettlementWitness>? settlementWitnesses,
    List<PercMicroblockLogEntry>? microblockLog,
    PercChronofluxMicroVerifier? microVerifier,
  })  : walletPeers = walletPeers ?? <String, List<String>>{},
        networkNodes = networkNodes ?? <String, PercPeerNode>{},
        evolvedAppVersions = evolvedAppVersions ?? [],
        evolutionSteps = evolutionSteps ?? [],
        wardProposals = wardProposals ?? [],
        wardBallots = wardBallots ?? [],
        pendingInboundTransfers = pendingInboundTransfers ?? [],
        settlementWitnesses = settlementWitnesses ?? [],
        microblockLog = microblockLog ?? [],
        cumulativeBurnedPerc = cumulativeBurnedPerc ?? PercAmount.zero,
        _microVerifier = microVerifier ?? const PercChronofluxMicroVerifier();

  int get microblocksPerWard => PercChainConstants.microblocksPerWardEffective;

  final Map<String, PercAccount> accounts;
  final List<PercBlock> blocks;
  DateTime? lastScenarioAt;
  bool treasuryGenesisDone;
  PercAmount cumulativeTreasuryMinted;
  PercAmount cumulativeBurnedPerc;
  int treasuryCycle;
  bool blockchainLaunched;
  String? sessionUsername;
  DateTime? sessionStartedAt;
  DateTime? sessionLastActivityAt;
  int nextTxId;
  int microblockCount;
  int totalMicroblocks;
  String? lastChronofluxFingerprint;
  Map<String, List<String>> walletPeers;
  Map<String, PercPeerNode> networkNodes;
  String evolutionaryChainId;
  String chronofluxPrincipiaId;
  String mainChainId;
  String sideChainId;
  String connectedAppVersion;
  List<String> evolvedAppVersions;
  List<PercEvolutionStep> evolutionSteps;
  int evolutionEpoch;
  int networkGenesisRevision;
  final List<WardProposal> wardProposals;
  final List<WardBallot> wardBallots;
  int nextWardProposalId;
  final List<PercPendingInboundTransfer> pendingInboundTransfers;
  final List<PercSettlementWitness> settlementWitnesses;
  final List<PercMicroblockLogEntry> microblockLog;
  final PercChronofluxMicroVerifier _microVerifier;

  List<PercPendingInboundTransfer> pendingInboundFor(String username) {
    final u = PercAuth.normalizeUsername(username);
    return pendingInboundTransfers
        .where((p) => p.toUsername == u)
        .toList(growable: false);
  }

  bool get isOnEvolutionaryChain =>
      evolutionaryChainId == PercChainConstants.evolutionaryChainId ||
      evolutionaryChainId.isEmpty;
  bool _blockchainLaunchEventPending = false;
  bool _genesisRenewalEventPending = false;

  int get microblocksPerBlock =>
      PercChainConstants.microblocksPerBlockOverride ??
      PercChainConstants.microblocksPerBlock;

  double get microblockProgress =>
      microblocksPerBlock > 0 ? microblockCount / microblocksPerBlock : 0;

  bool get isWalletMeshComplete =>
      PercWalletMesh.isComplete(walletPeers, accounts.keys);

  List<String> connectedPeersFor(String username) {
    final key = PercAuth.normalizeUsername(username);
    return List.unmodifiable(walletPeers[key] ?? const []);
  }

  List<String> get sessionConnectedPeers =>
      sessionUsername == null ? const [] : connectedPeersFor(sessionUsername!);

  /// Ensures every wallet has concurrent peer links to every other wallet.
  void connectAllWalletsConcurrently() {
    final users = accounts.keys.toList();
    if (users.isEmpty) {
      walletPeers = {};
      networkNodes = {};
      return;
    }
    walletPeers = PercWalletMesh.fullMesh(users);
    ensureNetworkNodes(
      blockHeight: blockHeight,
      tipHash: PercChainTip.hash(this),
    );
  }

  /// Registers every account as an offline network node at the current chain tip.
  void ensureNetworkNodes({
    required int blockHeight,
    required String tipHash,
  }) {
    final now = DateTime.now().toUtc();
    final updated = <String, PercPeerNode>{};
    for (final username in accounts.keys) {
      final existing = networkNodes[username];
      updated[username] = existing?.copyWith(
            blockHeight: blockHeight,
            tipHash: tipHash,
            lastSeen: now,
          ) ??
          PercPeerNode.offline(
            username: username,
            blockHeight: blockHeight,
            tipHash: tipHash,
            lastSeen: now,
          );
    }
    networkNodes = updated;
  }

  void setWalletOnline(
    String username, {
    String? endpoint,
    required int blockHeight,
    required String tipHash,
  }) {
    final key = PercAuth.normalizeUsername(username);
    final now = DateTime.now().toUtc();
    final existing = networkNodes[key];
    networkNodes[key] = (existing ??
            PercPeerNode.offline(
              username: key,
              blockHeight: blockHeight,
              tipHash: tipHash,
            ))
        .copyWith(
      endpoint: endpoint,
      blockHeight: blockHeight,
      tipHash: tipHash,
      online: true,
      lastSeen: now,
    );
  }

  void setWalletOffline(
    String username, {
    required int blockHeight,
    required String tipHash,
  }) {
    final key = PercAuth.normalizeUsername(username);
    final existing = networkNodes[key];
    if (existing == null) return;
    networkNodes[key] = existing.copyWith(
      online: false,
      endpoint: null,
      blockHeight: blockHeight,
      tipHash: tipHash,
      lastSeen: DateTime.now().toUtc(),
    );
  }

  void updatePeerFromStatus(
    PercNetworkStatus status, {
    bool? online,
  }) {
    final username = status.sessionUsername;
    final address = status.walletAddress?.trim();
    if (username == null && (address == null || address.isEmpty)) return;
    final key = username != null
        ? PercAuth.normalizeUsername(username)
        : PercAccountPrivacy.peerKeyForAddress(address!);
    final existing = networkNodes[key];
    final isOnline = online ?? status.isFreshOnSeedPeer;
    networkNodes[key] = (existing ??
            PercPeerNode.offline(
              username: username != null ? key : key,
              blockHeight: status.blockHeight,
              tipHash: status.tipHash,
            ))
        .copyWith(
      endpoint: status.endpoint ?? existing?.endpoint,
      blockHeight: status.blockHeight,
      tipHash: status.tipHash,
      online: isOnline,
      lastSeen: status.updatedAt?.toUtc() ?? DateTime.now().toUtc(),
    );
  }

  bool isWalletOnlineOnNetwork(String username) {
    final key = PercAuth.normalizeUsername(username);
    if (key == PercChainConstants.treasuryUsername && blockchainLaunched) {
      return true;
    }
    return networkNodes[key]?.online ?? false;
  }

  List<PercPeerNode> get onlineNetworkNodes => networkNodes.values
      .where((node) => node.online)
      .toList(growable: false);

  int get networkCanonicalHeight {
    var maxHeight = blockHeight;
    for (final node in networkNodes.values) {
      if (node.blockHeight > maxHeight) maxHeight = node.blockHeight;
    }
    return maxHeight;
  }

  bool get isAlignedToNetworkHeight => blockHeight >= networkCanonicalHeight;

  /// Replaces local chain state with a taller peer ledger on the evolutionary chain.
  void importPeerLedger(
    PercLedger remote, {
    String? expectedTipHash,
    bool force = false,
  }) {
    mergeNetworkStateFromPeer(remote);

    final remoteChainId = remote.evolutionaryChainId.isEmpty
        ? PercChainConstants.evolutionaryChainId
        : remote.evolutionaryChainId;
    final localChainId = evolutionaryChainId.isEmpty
        ? PercChainConstants.evolutionaryChainId
        : evolutionaryChainId;
    if (remoteChainId != localChainId) {
      throw StateError('Peer chain id mismatch');
    }
    if (remote.networkGenesisRevision > networkGenesisRevision) {
      _applyRemoteLedger(remote, preserveLocalWallets: false);
      return;
    }
    if (!force && remote.blockHeight < blockHeight) return;
    if (!force && remote.blockHeight == blockHeight) {
      final remoteTip = PercChainTip.hash(remote);
      if (expectedTipHash != null &&
          expectedTipHash.isNotEmpty &&
          remoteTip != expectedTipHash) {
        throw StateError('Peer chain tip mismatch at equal height');
      }
      return;
    }

    _applyRemoteLedger(
      remote,
      preserveLocalWallets: !force,
      expectedTipHash: expectedTipHash,
      force: force,
    );
  }

  void resetFromSeedLedger(PercLedger seed, {String? expectedTipHash}) {
    _applyRemoteLedger(
      seed,
      preserveLocalWallets: false,
      expectedTipHash: expectedTipHash,
      force: true,
    );
  }

  void _applyRemoteLedger(
    PercLedger remote, {
    required bool preserveLocalWallets,
    String? expectedTipHash,
    bool force = false,
  }) {
    if (!force && remote.blockHeight == blockHeight) {
      final remoteTip = PercChainTip.hash(remote);
      if (expectedTipHash != null &&
          expectedTipHash.isNotEmpty &&
          remoteTip != expectedTipHash) {
        throw StateError('Peer chain tip mismatch at equal height');
      }
      if (!force) return;
    }

    final session = sessionUsername;
    final localWallets = preserveLocalWallets
        ? _snapshotIndependentWallets()
        : <String, PercAccount>{};
    accounts
      ..clear()
      ..addAll(remote.accounts);
    blocks
      ..clear()
      ..addAll(remote.blocks);
    lastScenarioAt = remote.lastScenarioAt;
    treasuryGenesisDone = remote.treasuryGenesisDone;
    cumulativeTreasuryMinted = remote.cumulativeTreasuryMinted;
    cumulativeBurnedPerc = remote.cumulativeBurnedPerc;
    treasuryCycle = remote.treasuryCycle;
    blockchainLaunched = remote.blockchainLaunched;
    nextTxId = remote.nextTxId;
    microblockCount = remote.microblockCount;
    totalMicroblocks = remote.totalMicroblocks;
    lastChronofluxFingerprint = remote.lastChronofluxFingerprint;
    microblockLog
      ..clear()
      ..addAll(remote.microblockLog);
    walletPeers
      ..clear()
      ..addAll(
        remote.walletPeers.map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        ),
      );
    networkNodes
      ..clear()
      ..addAll(remote.networkNodes);
    evolutionaryChainId = remote.evolutionaryChainId;
    chronofluxPrincipiaId = remote.chronofluxPrincipiaId;
    mainChainId = remote.mainChainId;
    sideChainId = remote.sideChainId;
    connectedAppVersion = remote.connectedAppVersion;
    evolvedAppVersions = List<String>.from(remote.evolvedAppVersions);
    evolutionSteps = List<PercEvolutionStep>.from(remote.evolutionSteps);
    evolutionEpoch = remote.evolutionEpoch;
    networkGenesisRevision = remote.networkGenesisRevision;
    wardProposals
      ..clear()
      ..addAll(remote.wardProposals);
    wardBallots
      ..clear()
      ..addAll(remote.wardBallots);
    nextWardProposalId = remote.nextWardProposalId;
    pendingInboundTransfers
      ..clear()
      ..addAll(remote.pendingInboundTransfers);

    if (preserveLocalWallets) {
      _restoreIndependentWallets(localWallets);
    }

    if (session != null && !accounts.containsKey(session)) {
      sessionUsername = null;
      sessionStartedAt = null;
      sessionLastActivityAt = null;
    }
    repairForAppUpgrade();
  }

  /// Local wallets with credentials — preserved across network chain imports.
  Map<String, PercAccount> _snapshotIndependentWallets() {
    final snap = <String, PercAccount>{};
    for (final entry in accounts.entries) {
      final username = entry.key;
      if (username == PercChainConstants.seedUsername) continue;
      final acc = entry.value;
      if (!acc.passwordSet) continue;
      snap[username] = PercAccount(
        username: acc.username,
        passwordHash: acc.passwordHash,
        salt: acc.salt,
        address: acc.address,
        passwordSet: true,
        balance: acc.balance,
        lastFaucetDrawAt: acc.lastFaucetDrawAt,
        cumulativeStakingEarned: acc.cumulativeStakingEarned,
        scenarioBlockHeight: acc.scenarioBlockHeight,
        transactions: List<PercTransaction>.from(acc.transactions),
      );
    }
    return snap;
  }

  void _restoreIndependentWallets(Map<String, PercAccount> localWallets) {
    for (final entry in localWallets.entries) {
      final username = entry.key;
      final local = entry.value;
      final aliasKeys = accounts.entries
          .where(
            (e) =>
                e.key != username &&
                e.value.address == local.address &&
                !e.value.passwordSet,
          )
          .map((e) => e.key)
          .toList();
      for (final alias in aliasKeys) {
        _rewriteUsernameReferences(alias, username);
        accounts.remove(alias);
      }

      final remote = accounts[username];
      if (remote == null) {
        accounts[username] = local;
        continue;
      }
      remote.passwordHash = local.passwordHash;
      remote.salt = local.salt;
      remote.passwordSet = true;
      remote.balance = local.balance;
      remote.lastFaucetDrawAt = local.lastFaucetDrawAt;
      remote.cumulativeStakingEarned = local.cumulativeStakingEarned;
      remote.scenarioBlockHeight = local.scenarioBlockHeight;
      remote.transactions
        ..clear()
        ..addAll(local.transactions);
    }
  }

  /// Adopts launch flags from the internet seed without replacing local chain state.
  void adoptNetworkLaunchState(PercLedger remote) {
    if (!remote.blockchainLaunched) return;
    blockchainLaunched = true;
    if (remote.treasuryGenesisDone) {
      treasuryGenesisDone = true;
    }
    if (remote.networkGenesisRevision > networkGenesisRevision) {
      networkGenesisRevision = remote.networkGenesisRevision;
    }
  }

  static PercLedger empty() {
    final ledger = PercLedger(
      accounts: {},
      blocks: [],
      lastScenarioAt: null,
      treasuryGenesisDone: false,
      cumulativeTreasuryMinted: PercAmount.zero,
      treasuryCycle: 1,
      blockchainLaunched: false,
    );
    return ledger;
  }

  /// User proposals listed for all wallets for [WardProposal.listingDays] days.
  List<WardProposal> openWardProposals([DateTime? now]) =>
      WardVoting.listedForAll(proposals: wardProposals, now: now);

  WardProposal submitWardProposal({
    required String proposerUsername,
    required String title,
    required String summary,
    required String wardName,
    DateTime? now,
  }) {
    final u = PercAuth.normalizeUsername(proposerUsername);
    if (title.trim().isEmpty || summary.trim().isEmpty) {
      throw StateError('Proposal title and summary are required');
    }
    if (wardName.trim().isEmpty) {
      throw StateError('Ward name is required');
    }
    final t = (now ?? DateTime.now()).toUtc();
    final proposal = WardVoting.createUserProposal(
      id: 'ward-user-$nextWardProposalId',
      title: title,
      summary: summary,
      wardName: wardName,
      proposerUsername: u,
      now: t,
    );
    nextWardProposalId++;
    wardProposals.add(proposal);
    return proposal;
  }

  WardBallot? wardBallotFor({
    required String proposalId,
    required String voterUsername,
  }) =>
      WardVoting.ballotFor(
        ballots: wardBallots,
        proposalId: proposalId,
        voterUsername: voterUsername,
      );

  Map<WardVoteChoice, int> wardTallyFor(String proposalId) =>
      WardVoting.tallyFor(ballots: wardBallots, proposalId: proposalId);

  int wardTotalVotesFor(String proposalId) =>
      WardVoting.totalVotesFor(ballots: wardBallots, proposalId: proposalId);

  List<WardBallot> wardPublicBallotsFor(String proposalId) =>
      WardVoting.publicBallotsFor(ballots: wardBallots, proposalId: proposalId);

  /// One ballot per wallet per proposal — no recast once recorded.
  WardBallot castWardVote({
    required String proposalId,
    required String voterUsername,
    required WardVoteChoice choice,
    required String comment,
    DateTime? now,
  }) {
    final u = PercAuth.normalizeUsername(voterUsername);
    final proposal = wardProposals.firstWhere(
      (p) => p.id == proposalId,
      orElse: () => throw StateError('Unknown ward proposal'),
    );
    final t = (now ?? DateTime.now()).toUtc();
    if (!proposal.isOpenAt(t)) {
      throw StateError('Proposal listing has ended');
    }
    final trimmed = comment.trim();
    final existing = wardBallotFor(proposalId: proposalId, voterUsername: u);
    if (existing != null) {
      throw StateError('This wallet already voted on this proposal');
    }
    final ballot = WardBallot(
      proposalId: proposalId,
      voterUsername: u,
      choice: choice,
      comment: trimmed,
      castAt: t,
    );
    wardBallots.add(ballot);
    return ballot;
  }

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

  PercAccount? account(String username) =>
      _accountFor(PercAuth.normalizeUsername(username));

  PercAccount? accountForAddress(String address) =>
      _accountForAddress(PercAuth.normalizeAddress(address));

  /// Stubs discoverable wallets from a peer/seed ledger so sends can target them.
  void mergeDiscoverableAccounts(PercLedger remote) {
    for (final acc in remote.accounts.values) {
      if (acc.address.isEmpty) continue;
      if (_accountForAddress(acc.address) != null) continue;
      if (acc.username == PercChainConstants.treasuryUsername ||
          acc.username == PercChainConstants.seedUsername) {
        continue;
      }
      try {
        ensureRemoteAccount(username: acc.username, address: acc.address);
      } on StateError {
        // Username collision with a different local address — skip.
      }
    }
  }

  /// Merges launch flags, address book, and inbound transfers without replacing chain tip.
  void mergeNetworkStateFromPeer(PercLedger remote) {
    adoptNetworkLaunchState(remote);
    mergeDiscoverableAccounts(remote);
    applyInboundRelayFromSender(remote);
    reconcileSettledTransfersFromPeer(remote);
    final session = sessionUsername;
    if (session != null) {
      refreshPendingInboundTransfers();
    }
  }

  /// Sender-side ingest after receiver scenario emits a settlement witness.
  void ingestSettlementWitnessFromReceiver(PercLedger receiver) {
    mergeNetworkStateFromPeer(receiver);
  }

  bool _transferBlockExists(String transferId) {
    for (final block in blocks) {
      for (final tx in block.transactions) {
        if (tx.id == transferId && tx.kind == PercTxKind.transfer) return true;
      }
    }
    return false;
  }

  void mergePendingInboundFromPeer(PercLedger remote) {
    final seen = pendingInboundTransfers.map((p) => p.id).toSet();
    for (final pending in remote.pendingInboundTransfers) {
      if (seen.contains(pending.id)) continue;
      final recipient = _localWalletForRemoteParty(pending.toUsername, remote);
      if (recipient == null) continue;
      final localPending = PercPendingInboundTransfer(
        id: pending.id,
        fromUsername: pending.fromUsername,
        toUsername: recipient.username,
        amount: pending.amount,
        fee: pending.fee,
        sentAt: pending.sentAt,
        memo: pending.memo,
        recipientBroughtOnlineAt: pending.recipientBroughtOnlineAt,
      );
      pendingInboundTransfers.add(localPending);
      _ensurePendingInboundTxListed(recipient, localPending);
      _ensurePendingOutboundTxListed(pending.fromUsername, localPending);
      seen.add(pending.id);
    }
  }

  /// Pulls transfer txs from a shorter/divergent peer chain (cross-version gossip).
  void mergeInboundTransferTxsFromPeer(PercLedger remote) {
    final knownIds = <String>{};
    for (final acc in accounts.values) {
      for (final tx in acc.transactions) {
        knownIds.add(tx.id);
      }
    }
    final remotePendingIds =
        remote.pendingInboundTransfers.map((p) => p.id).toSet();
    for (final block in remote.blocks) {
      for (final tx in block.transactions) {
        if (tx.kind != PercTxKind.transfer) continue;
        if (tx.isConfirmed) continue;
        if (!remotePendingIds.contains(tx.id)) continue;
        if (knownIds.contains(tx.id)) continue;
        if (pendingInboundTransfers.any((p) => p.id == tx.id)) continue;
        final toUser = tx.toUsername;
        if (toUser == null || toUser.isEmpty) continue;
        final recipient = _localWalletForRemoteParty(toUser, remote);
        if (recipient == null) continue;
        final localPending = PercPendingInboundTransfer(
          id: tx.id,
          fromUsername: tx.fromUsername ?? '',
          toUsername: recipient.username,
          amount: tx.amount,
          sentAt: tx.timestamp,
          memo: tx.memo,
        );
        pendingInboundTransfers.add(localPending);
        _ensurePendingInboundTxListed(recipient, localPending);
        if (localPending.fromUsername.isNotEmpty) {
          _ensurePendingOutboundTxListed(localPending.fromUsername, localPending);
        }
        knownIds.add(tx.id);
      }
    }
  }

  PercAccount? _localWalletForRemoteParty(String remoteUsername, PercLedger remote) {
    PercAccount? remoteParty;
    for (final acc in remote.accounts.values) {
      if (acc.username == remoteUsername) {
        remoteParty = acc;
        break;
      }
    }
    if (remoteParty != null && remoteParty.address.isNotEmpty) {
      for (final local in accounts.values) {
        if (local.passwordSet && local.address == remoteParty!.address) {
          return local;
        }
      }
    }
    final direct = _accountFor(remoteUsername);
    if (direct != null && direct.passwordSet) return direct;
    return null;
  }

  PercAccount? _accountForAddress(String address) {
    final normalized = PercAuth.normalizeAddress(address);
    if (normalized.isEmpty) return null;
    for (final acc in accounts.values) {
      if (acc.address == normalized) return acc;
    }
    return null;
  }

  /// Registers a network-discovered wallet so sends can target QR-scanned addresses.
  PercAccount ensureRemoteAccount({
    required String username,
    required String address,
  }) {
    final u = PercAuth.normalizeUsername(username);
    final addr = PercAuth.normalizeAddress(address);
    if (PercAuth.validateAddress(addr) != null) {
      throw StateError('Invalid remote wallet address');
    }

    final byAddr = _accountForAddress(addr);
    if (byAddr != null) return byAddr;

    final existing = accounts[u];
    if (existing != null) {
      if (existing.address == addr) return existing;
      throw StateError('Username already registered with a different address');
    }

    final acc = PercAccount(
      username: u,
      passwordHash: '',
      salt: '',
      address: addr,
      passwordSet: false,
    );
    accounts[u] = acc;
    connectAllWalletsConcurrently();
    return acc;
  }

  bool get isLoggedIn => sessionUsername != null;

  DateTime? walletSessionExpiresAt({DateTime? now}) {
    if (sessionUsername == null) return null;
    if (sessionStartedAt == null || sessionLastActivityAt == null) {
      return (now ?? DateTime.now()).toUtc();
    }
    final maxEnd = sessionStartedAt!.add(
      PercChainConstants.walletSessionMaxDurationEffective,
    );
    final idleEnd = sessionLastActivityAt!.add(
      PercChainConstants.walletSessionIdleTimeoutEffective,
    );
    return maxEnd.isAfter(idleEnd) ? maxEnd : idleEnd;
  }

  bool isWalletSessionExpired({DateTime? now}) {
    if (sessionUsername == null) return false;
    final expiresAt = walletSessionExpiresAt(now: now);
    if (expiresAt == null) return false;
    final at = (now ?? DateTime.now()).toUtc();
    return !at.isBefore(expiresAt);
  }

  Duration? walletSessionRemaining({DateTime? now}) {
    if (sessionUsername == null) return null;
    final expiresAt = walletSessionExpiresAt(now: now);
    if (expiresAt == null) return Duration.zero;
    final at = (now ?? DateTime.now()).toUtc();
    final remaining = expiresAt.difference(at);
    if (remaining <= Duration.zero) return Duration.zero;
    return remaining;
  }

  void touchWalletSessionActivity({DateTime? now}) {
    if (sessionUsername == null) return;
    sessionLastActivityAt = (now ?? DateTime.now()).toUtc();
  }

  PercAccount? get sessionAccount => sessionUsername == null
      ? null
      : _accountFor(PercAuth.normalizeUsername(sessionUsername!));

  PercAccount? _accountFor(String username) {
    final direct = accounts[username];
    if (direct != null) return direct;
    final treasury = PercChainConstants.treasuryUsername;
    if (username == treasury) {
      for (final legacy in legacyTreasuryUsernames) {
        final acc = accounts[legacy];
        if (acc != null) return acc;
      }
    }
    return null;
  }

  PercAmount get treasuryBalance =>
      accounts[PercChainConstants.treasuryUsername]?.balance ?? PercAmount.zero;

  /// Spendable balance — excludes PERC reserved for outbound transfers awaiting
  /// network settlement.
  PercAmount get sessionBalance {
    final acc = sessionAccount;
    if (acc == null) return PercAmount.zero;
    return _spendableBalance(acc);
  }

  PercAmount _spendableBalance(PercAccount account) =>
      account.balance - _pendingOutboundHold(account.username);

  PercAmount _pendingOutboundHold(String username) {
    final from = PercAuth.normalizeUsername(username);
    return pendingInboundTransfers
        .where((p) => p.fromUsername == from)
        .fold<PercAmount>(PercAmount.zero, (sum, p) => sum + p.totalHold);
  }

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

  double get treasuryProgress {
    if (PercChainConstants.infiniteContinuumSupply) {
      final minted = cumulativeTreasuryMinted.asPerc;
      if (minted <= 0) return 0;
      return (minted / (minted + 1)).clamp(0.0, 0.9999);
    }
    return cumulativeTreasuryMinted.asPerc /
        PercChainConstants.poolRenewalAllocation.asPerc;
  }

  bool get treasuryCapped =>
      !PercChainConstants.infiniteContinuumSupply &&
      cumulativeTreasuryMinted >= PercChainConstants.poolRenewalAllocation;

  PercAmount get treasuryRemaining {
    if (PercChainConstants.infiniteContinuumSupply) {
      return PercAmount.fromPerc(999999999);
    }
    return PercChainConstants.poolRenewalAllocation - cumulativeTreasuryMinted;
  }

  Duration? get averageTimePerBlock =>
      PercBlockTiming.averageTimePerBlock(blocks);

  DateTime? get lastInflationEpoch =>
      PercInflation.lastInflationEpoch(blocks);

  bool get treasuryPoolCritical =>
      PercInflation.isPoolCritical(treasuryBalance);

  PercEmissionContext get emissionContext =>
      PercDynamicEmission.contextFromLedger(this);

  PercAmount get dynamicTreasuryEmissionPerMinute =>
      PercDynamicEmission.effectiveEmissionPerMinute(emissionContext);

  String get dynamicTreasuryEmissionPerMinuteLabel =>
      dynamicTreasuryEmissionPerMinute.displayFixed8;

  int get emissionLoadFactorPercent =>
      PercDynamicEmission.loadFactorPercent(emissionContext);

  int get emissionBlockTimeFactorPercent =>
      PercDynamicEmission.blockTimeFactorPercent(emissionContext);

  bool get treasuryNeedsRegeneration =>
      blockchainLaunched &&
      PercInflation.needsRegeneration(
        treasuryBalance,
        emissionContext: emissionContext,
      );

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
        emissionContext: emissionContext,
        now: (now ?? DateTime.now()).toUtc(),
      );

  bool treasuryNeedsPasswordSetup() {
    final t = _accountFor(PercChainConstants.treasuryUsername);
    return t != null && !t.passwordSet;
  }

  bool hasAccount(String username) =>
      accounts.containsKey(PercAuth.normalizeUsername(username));

  String _newTxId() => 'tx-${nextTxId++}';

  void ensureTreasuryAccount() => _ensureTreasury();

  /// One-shot repair when opening a newer app over a saved ledger (seamless upgrade).
  void repairForAppUpgrade() {
    migrateLegacyTreasuryAccounts();
    ensureTreasuryAccount();
    _sanitizeWalletPeers();
    repairEvolutionChain();
    connectAllWalletsConcurrently();
    _migrateLegacyTransferFeesToBurn();
    _reconcileCumulativeBurnedPerc();
    _backfillScenarioBlockHeights();
  }

  /// Advances the user's numerically progressive scenario block (1 per conclusion, max 100M).
  int advanceScenarioBlock(
    String username, {
    PercLedger? senderPeer,
    PercSenderPeerResolver? senderPeerResolver,
  }) {
    final acc = _accountFor(PercAuth.normalizeUsername(username));
    if (acc == null) return 0;
    if (acc.scenarioBlockHeight >= PercChainConstants.maxScenarioBlocksPerWallet) {
      return acc.scenarioBlockHeight;
    }
    acc.scenarioBlockHeight++;
    settlePendingInboundOnActivity(
      username,
      senderPeer: senderPeer,
      senderPeerResolver: senderPeerResolver,
    );
    return acc.scenarioBlockHeight;
  }

  /// Sender username for a transfer id (blocks + account tx lists).
  String? lookupTransferSender(String transferId) {
    for (final block in blocks) {
      for (final tx in block.transactions) {
        if (tx.id == transferId &&
            tx.kind == PercTxKind.transfer &&
            tx.fromUsername != null) {
          return tx.fromUsername;
        }
      }
    }
    for (final acc in accounts.values) {
      for (final tx in acc.transactions) {
        if (tx.id == transferId &&
            tx.kind == PercTxKind.transfer &&
            tx.fromUsername != null) {
          return tx.fromUsername;
        }
      }
    }
    return null;
  }

  /// Block index used when a mutation is confirmed at seed/network height while
  /// the local chain tip may still be shorter.
  int _seedConfirmationBlockIndex({int? seedConfirmationBlockHeight}) {
    final network = seedConfirmationBlockHeight ?? networkCanonicalHeight;
    final localNext = blocks.length;
    return network > localNext ? network : localNext;
  }

  void _backfillScenarioBlockHeights() {
    for (final acc in accounts.values) {
      if (acc.scenarioBlockHeight > 0) continue;
      final concluded = blocks
          .where(
            (b) =>
                b.triggerUsername == acc.username &&
                b.scenarioLabel != null &&
                !b.microblockSeal,
          )
          .length;
      if (concluded > 0) {
        acc.scenarioBlockHeight = concluded.clamp(
          0,
          PercChainConstants.maxScenarioBlocksPerWallet,
        );
      }
    }
  }

  PercTransaction _burnTransactionFee({
    required PercAmount fee,
    required String fromUsername,
    required DateTime timestamp,
    required PercAccount sender,
  }) {
    cumulativeBurnedPerc = cumulativeBurnedPerc + fee;
    final feeTx = PercTransaction(
      id: _newTxId(),
      kind: PercTxKind.feeBurn,
      amount: fee,
      timestamp: timestamp,
      fromUsername: fromUsername,
      memo: 'Burned network fee',
      blockIndex: blocks.length,
      confirmations: _txConfirmations,
    );
    sender.transactions.insert(0, feeTx);
    return feeTx;
  }

  void _migrateLegacyTransferFeesToBurn() {
    final treasury = _accountFor(PercChainConstants.treasuryUsername);
    if (treasury == null) return;

    for (final block in blocks) {
      for (final tx in block.transactions) {
        if (tx.toUsername != PercChainConstants.treasuryUsername) continue;
        if (tx.memo != 'Network fee') continue;
        if (treasury.balance >= tx.amount) {
          treasury.balance = treasury.balance - tx.amount;
        }
      }
    }
  }

  PercAmount _burnedFeesFromChain() {
    var total = PercAmount.zero;
    for (final block in blocks) {
      for (final tx in block.transactions) {
        if (tx.kind == PercTxKind.feeBurn) {
          total = total + tx.amount;
        }
      }
    }
    return total;
  }

  void _reconcileCumulativeBurnedPerc() {
    cumulativeBurnedPerc = _burnedFeesFromChain();
  }

  /// Rebuilds wallet peer mesh keys and backfills parent links between app versions.
  void repairEvolutionChain() {
    if (evolutionSteps.isEmpty && evolvedAppVersions.isNotEmpty) {
      final rebuilt = <PercEvolutionStep>[];
      for (var i = 0; i < evolvedAppVersions.length; i++) {
        final version = evolvedAppVersions[i];
        final parentVersion = i == 0 ? '' : evolvedAppVersions[i - 1];
        final parentFp = i == 0 ? '' : rebuilt[i - 1].chronofluxFingerprint;
        rebuilt.add(
          PercEvolutionStep(
            appVersion: version,
            timestamp: lastScenarioAt ?? DateTime.now().toUtc(),
            chronofluxFingerprint: lastChronofluxFingerprint ?? parentFp,
            blockHeight: blockHeight,
            microblockHeight: totalMicroblocks,
            evolutionEpoch: i + 1,
            previousAppVersion: parentVersion,
            parentChronofluxFingerprint: parentFp,
          ),
        );
      }
      evolutionSteps = rebuilt;
    } else if (evolutionSteps.isNotEmpty) {
      evolvedAppVersions = evolutionSteps.map((s) => s.appVersion).toList();
    }

    if (evolutionSteps.isNotEmpty) {
      final linked = <PercEvolutionStep>[];
      for (var i = 0; i < evolutionSteps.length; i++) {
        var step = evolutionSteps[i];
        final parent = i == 0 ? null : linked[i - 1];
        if (!step.hasParentLink && parent != null) {
          step = step.copyWith(
            previousAppVersion: parent.appVersion,
            parentChronofluxFingerprint: parent.chronofluxFingerprint,
          );
        }
        linked.add(step);
      }
      evolutionSteps = linked;
      evolvedAppVersions = linked.map((s) => s.appVersion).toList();
      evolutionEpoch = linked.length + 1;
      lastChronofluxFingerprint ??= linked.last.chronofluxFingerprint;
    } else {
      evolutionEpoch = 1;
    }
  }

  void _sanitizeWalletPeers() {
    final users = accounts.keys.toSet();
    if (users.isEmpty) {
      walletPeers = {};
      return;
    }
    final sanitized = <String, List<String>>{};
    for (final user in users) {
      final peers = (walletPeers[user] ?? const <String>[])
          .where(users.contains)
          .where((peer) => peer != user)
          .toSet()
          .toList()
        ..sort();
      sanitized[user] = peers;
    }
    walletPeers = sanitized;
  }

  /// Merges legacy treasury keys (e.g. rgsneddon) into evolve_treasury after renames.
  void migrateLegacyTreasuryAccounts() {
    final current = PercChainConstants.treasuryUsername;
    for (final legacy in legacyTreasuryUsernames) {
      if (legacy == current || !accounts.containsKey(legacy)) continue;

      final legacyAcc = accounts.remove(legacy)!;
      final existing = accounts[current];

      if (existing == null) {
        accounts[current] = PercAccount(
          username: current,
          passwordHash: legacyAcc.passwordHash,
          salt: legacyAcc.salt,
          address: legacyAcc.address,
          passwordSet: legacyAcc.passwordSet,
          balance: legacyAcc.balance,
          lastFaucetDrawAt: legacyAcc.lastFaucetDrawAt,
          cumulativeStakingEarned: legacyAcc.cumulativeStakingEarned,
          transactions: List<PercTransaction>.from(legacyAcc.transactions),
        );
      } else {
        if (!existing.passwordSet && legacyAcc.passwordSet) {
          existing.passwordHash = legacyAcc.passwordHash;
          existing.salt = legacyAcc.salt;
          existing.passwordSet = true;
        }
        existing.balance = existing.balance + legacyAcc.balance;
        existing.cumulativeStakingEarned =
            existing.cumulativeStakingEarned + legacyAcc.cumulativeStakingEarned;
        if (existing.lastFaucetDrawAt == null) {
          existing.lastFaucetDrawAt = legacyAcc.lastFaucetDrawAt;
        }
        existing.transactions.insertAll(0, legacyAcc.transactions);
      }

      _rewriteUsernameReferences(legacy, current);
    }

    _normalizeSessionUsername();
    connectAllWalletsConcurrently();
  }

  void _normalizeSessionUsername() {
    if (sessionUsername == null) return;
    final normalized = PercAuth.normalizeUsername(sessionUsername!);
    if (legacyTreasuryUsernames.contains(normalized)) {
      sessionUsername = PercChainConstants.treasuryUsername;
      return;
    }
    sessionUsername = normalized;
    if (!accounts.containsKey(sessionUsername)) {
      sessionUsername = null;
    }
  }

  void _rewriteUsernameReferences(String from, String to) {
    if (sessionUsername == from) sessionUsername = to;

    final remappedPeers = <String, List<String>>{};
    for (final entry in walletPeers.entries) {
      final key = entry.key == from ? to : entry.key;
      remappedPeers[key] = entry.value.map((p) => p == from ? to : p).toList()
        ..sort();
    }
    walletPeers = remappedPeers;

    for (final acc in accounts.values) {
      final txs = acc.transactions
          .map((tx) => _remapTxUsernames(tx, from, to))
          .toList();
      acc.transactions
        ..clear()
        ..addAll(txs);
    }

    final remappedBlocks = blocks
        .map(
          (b) => PercBlock(
            index: b.index,
            timestamp: b.timestamp,
            transactions: b.transactions
                .map((tx) => _remapTxUsernames(tx, from, to))
                .toList(),
            treasuryEmitted: b.treasuryEmitted,
            scenarioLabel: b.scenarioLabel,
            triggerUsername:
                b.triggerUsername == from ? to : b.triggerUsername,
            treasuryCycle: b.treasuryCycle,
            isGenesisRenewal: b.isGenesisRenewal,
            confirmations: b.confirmations,
            microblockSeal: b.microblockSeal,
            chronofluxFingerprint: b.chronofluxFingerprint,
            microblocksSealed: b.microblocksSealed,
          ),
        )
        .toList();
    blocks
      ..clear()
      ..addAll(remappedBlocks);

    final remappedPending = pendingInboundTransfers
        .map(
          (pending) => PercPendingInboundTransfer(
            id: pending.id,
            fromUsername: pending.fromUsername == from
                ? to
                : pending.fromUsername,
            toUsername: pending.toUsername == from ? to : pending.toUsername,
            amount: pending.amount,
            fee: pending.fee,
            sentAt: pending.sentAt,
            memo: pending.memo,
            recipientBroughtOnlineAt: pending.recipientBroughtOnlineAt,
          ),
        )
        .toList();
    pendingInboundTransfers
      ..clear()
      ..addAll(remappedPending);
  }

  PercTransaction _remapTxUsernames(
    PercTransaction tx,
    String from,
    String to,
  ) =>
      PercTransaction(
        id: tx.id,
        kind: tx.kind,
        amount: tx.amount,
        timestamp: tx.timestamp,
        fromUsername: tx.fromUsername == from ? to : tx.fromUsername,
        toUsername: tx.toUsername == from ? to : tx.toUsername,
        memo: tx.memo?.replaceAll(from, to),
        scenarioLabel: tx.scenarioLabel,
        percentChance: tx.percentChance,
        blockIndex: tx.blockIndex,
        confirmations: tx.confirmations,
        chronofluxFingerprint: tx.chronofluxFingerprint,
        microblockIndex: tx.microblockIndex,
        continuumScs: tx.continuumScs,
        vortexScs: tx.vortexScs,
        shearScs: tx.shearScs,
        resistanceScs: tx.resistanceScs,
        flowScs: tx.flowScs,
      );

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
      !PercChainConstants.infiniteContinuumSupply && isTreasuryAtReserve;

  /// Mints toward the per-minute emission target when balance falls below 66%.
  List<PercTransaction> _regenerateTreasuryIfNeeded(DateTime now) {
    // Genesis scenario emission mints the first minute allocation — skip regen until then.
    if (!treasuryGenesisDone) return [];
    if (!treasuryNeedsRegeneration || treasuryCapped) return [];

    final treasury = _ensureTreasury();
    final target = dynamicTreasuryEmissionPerMinute;
    final threshold = PercDynamicEmission.regenerationThreshold(emissionContext);
    final shortfall = target - treasury.balance;
    if (!shortfall.isPositive) return [];

    cumulativeTreasuryMinted = cumulativeTreasuryMinted + shortfall;
    _credit(treasury, shortfall);
    final tx = PercTransaction(
      id: _newTxId(),
      kind: PercTxKind.treasuryEmission,
      amount: shortfall,
      timestamp: now,
      toUsername: PercChainConstants.treasuryUsername,
      memo:
          'Treasury regeneration — balance below ${threshold.display} ${PercChainConstants.currencySymbol}',
      blockIndex: blocks.length,
      confirmations: _txConfirmations,
    );
    treasury.transactions.insert(0, tx);
    return [tx];
  }

  List<PercTransaction> _renewTreasuryPoolIfNeeded(DateTime now) {
    if (!_needsTreasuryPoolRenewal()) return [];

    treasuryCycle++;
    cumulativeTreasuryMinted = PercAmount.zero;
    treasuryGenesisDone = false;
    _genesisRenewalEventPending = true;

    final treasury = _ensureTreasury();
    _credit(treasury, PercChainConstants.poolRenewalAllocation);

    return [
      PercTransaction(
        id: _newTxId(),
        kind: PercTxKind.genesisRenewal,
        amount: PercChainConstants.poolRenewalAllocation,
        timestamp: now,
        toUsername: PercChainConstants.treasuryUsername,
        memo:
            'Treasury pool renewal — cycle $treasuryCycle (${PercChainConstants.poolRenewalAllocation.display} ${PercChainConstants.currencySymbol} minted to ${PercChainConstants.treasuryUsername})',
        blockIndex: blocks.length,
        confirmations: PercChainConstants.confirmationsRequired,
      ),
    ];
  }

  int get _txConfirmations => PercChainConstants.confirmationsRequired;

  void _assertTreasuryCanSend(String from) {
    if (from == PercChainConstants.treasuryUsername && isTreasurySendLocked) {
      throw StateError(
        'Manual sends disabled — ${PercChainConstants.treasuryUsername} cannot transfer PERC by hand after blockchain launch',
      );
    }
  }

  bool _treasuryCanDebit(PercAmount amount) {
    final treasury = _ensureTreasury();
    final after = treasury.balance - amount;
    return after.microUnits >=
        PercChainConstants.minimumTreasuryReserve.microUnits;
  }

  /// One-time launch allocation — credited before scenario payouts in a draw.
  PercAmount _treasuryBootstrapEmission() {
    if (treasuryGenesisDone || treasuryCapped) return PercAmount.zero;
    return PercChainConstants.treasuryLaunchAllocation;
  }

  /// Elapsed-time treasury accrual — applied after scenario payouts in a draw.
  PercAmount _treasuryAccrualEmissionForScenario(DateTime now) {
    if (treasuryCapped || !treasuryGenesisDone) return PercAmount.zero;
    if (lastScenarioAt == null) return PercAmount.zero;
    final elapsed = now.difference(lastScenarioAt!).inSeconds;
    if (elapsed <= 0) return PercAmount.zero;
    var emission =
        PercDynamicEmission.emissionForElapsedSeconds(elapsed, emissionContext);
    if (!PercChainConstants.infiniteContinuumSupply &&
        emission > treasuryRemaining) {
      emission = treasuryRemaining;
    }
    return emission;
  }

  void _appendTreasuryEmissionTx({
    required PercAmount amount,
    required DateTime now,
    required PercAccount treasury,
    required List<PercTransaction> blockTxs,
  }) {
    if (!amount.isPositive) return;
    cumulativeTreasuryMinted = cumulativeTreasuryMinted + amount;
    _credit(treasury, amount);
    final tx = PercTransaction(
      id: _newTxId(),
      kind: PercTxKind.treasuryEmission,
      amount: amount,
      timestamp: now,
      toUsername: PercChainConstants.treasuryUsername,
      blockIndex: blocks.length,
      confirmations: _txConfirmations,
    );
    treasury.transactions.insert(0, tx);
    blockTxs.add(tx);
  }

  void _credit(PercAccount acc, PercAmount amount) {
    acc.balance = acc.balance + amount;
  }

  /// Debits spendable balance — cannot consume PERC reserved for outbound holds.
  void _debit(PercAccount acc, PercAmount amount) {
    if (acc.balance < amount) {
      throw StateError(
        'Insufficient ${PercChainConstants.currencyName} balance',
      );
    }
    final after = acc.balance - amount;
    final reserved = _pendingOutboundHold(acc.username);
    if (after < reserved) {
      throw StateError(
        'Insufficient spendable balance — PERC reserved for pending outbound transfer',
      );
    }
    acc.balance = after;
  }

  /// Debits a sender when an outbound hold is released at scenario settlement.
  void _debitForOutboundSettlement(PercAccount acc, PercAmount amount) {
    if (acc.balance < amount) {
      throw StateError(
        'Insufficient ${PercChainConstants.currencyName} balance for outbound settlement',
      );
    }
    acc.balance = acc.balance - amount;
  }

  bool _senderIsLocalWallet(String username) {
    final acc = _accountFor(username);
    return acc != null && acc.passwordSet;
  }

  bool _isLocalSettleableRecipient(String username) {
    final acc = _accountFor(username);
    return acc != null && acc.passwordSet;
  }

  PercAmount _sameBlockIncomingFor(String username, List<PercTransaction> blockTxs) {
    var total = PercAmount.zero;
    for (final tx in blockTxs) {
      if (tx.toUsername != username) continue;
      if (tx.kind == PercTxKind.scenarioReward ||
          tx.kind == PercTxKind.transfer ||
          tx.kind == PercTxKind.transferRevert) {
        total = total + tx.amount;
      }
    }
    return total;
  }

  void _applyStakingRewards(DateTime now, List<PercTransaction> blockTxs) {
    final treasury = _ensureTreasury();
    final blockIndex = blocks.length;
    final holders = <String, PercAmount>{};

    for (final entry in accounts.entries) {
      if (entry.key == PercChainConstants.treasuryUsername) continue;
      final confirmed = PercStaking.confirmedBalanceForStaking(
        walletBalance: entry.value.balance,
        sameBlockIncoming: _sameBlockIncomingFor(entry.key, blockTxs),
      );
      if (confirmed.isPositive) {
        holders[entry.key] = confirmed;
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
    final regenTxs = _regenerateTreasuryIfNeeded(now);
    final genesisEmission = PercChainConstants.treasuryLaunchAllocation;
    if (!treasuryGenesisDone) {
      treasuryGenesisDone = true;
      cumulativeTreasuryMinted = cumulativeTreasuryMinted + genesisEmission;
      final treasury = _ensureTreasury();
      _credit(treasury, genesisEmission);
      return [
        ...regenTxs,
        PercTransaction(
          id: _newTxId(),
          kind: PercTxKind.treasuryEmission,
          amount: genesisEmission,
          timestamp: now,
          toUsername: PercChainConstants.treasuryUsername,
          blockIndex: blocks.length,
          confirmations: _txConfirmations,
        ),
      ];
    }
    if (lastScenarioAt == null) return regenTxs;
    final elapsed = now.difference(lastScenarioAt!).inSeconds;
    if (elapsed <= 0) return [];
    var emission =
        PercDynamicEmission.emissionForElapsedSeconds(elapsed, emissionContext);
    if (!PercChainConstants.infiniteContinuumSupply &&
        emission > treasuryRemaining) {
      emission = treasuryRemaining;
    }
    if (!emission.isPositive) return regenTxs;

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
    return [...regenTxs, tx];
  }

  void _appendMicroblockLog(PercMicroblockLogEntry entry) {
    microblockLog.add(entry);
    final cap = microblocksPerWard;
    if (cap > 0 && microblockLog.length > cap) {
      microblockLog.removeRange(0, microblockLog.length - cap);
    }
  }

  void _clearMicroblockLogForNextWard() {
    microblockLog.clear();
  }

  /// Each fair-usage event verifies the Chronoflux continuum and advances one microblock.
  PercMicroblockRecordResult recordMicroblock({
    required ScenarioInput input,
    LocaleConfig locale = LocaleConfig.defaults,
    DateTime? now,
    String activity = 'fair_usage',
    String? activityLabel,
  }) {
    if (!blockchainLaunched) return PercMicroblockRecordResult.skipped;

    final verification = _microVerifier.verify(input, locale: locale);
    if (!verification.selfConsistent) return PercMicroblockRecordResult.skipped;

    final stampedAt = (now ?? DateTime.now()).toUtc();
    microblockCount++;
    totalMicroblocks++;
    lastChronofluxFingerprint = verification.fingerprint;

    final perWard = microblocksPerWard;
    final cycleWardIndex =
        perWard > 0 ? (microblockCount - 1) ~/ perWard : 0;
    final wardMicroblock =
        perWard > 0 ? ((microblockCount - 1) % perWard) + 1 : 1;
    final wardComplete = perWard > 0 && wardMicroblock == perWard;
    final label = activityLabel ??
        (input.posedQuestion.trim().isNotEmpty
            ? input.posedQuestion.trim()
            : input.topic.trim());

    _appendMicroblockLog(
      PercMicroblockLogEntry(
        index: totalMicroblocks,
        timestamp: stampedAt,
        wardIndex: cycleWardIndex,
        wardMicroblock: wardMicroblock,
        activity: activity,
        label: label.isEmpty ? null : _truncateLabel(label),
        continuumPercent: verification.continuumPercent,
        fingerprint: verification.fingerprint,
      ),
    );

    if (!wardComplete) {
      return PercMicroblockRecordResult(
        recorded: true,
        microblockCount: microblockCount,
        selfConsistent: true,
      );
    }

    if (microblockCount < microblocksPerBlock) {
      _clearMicroblockLogForNextWard();
      return PercMicroblockRecordResult(
        recorded: true,
        microblockCount: microblockCount,
        selfConsistent: true,
        wardAdvanced: true,
      );
    }

    final sealedAt = (now ?? DateTime.now()).toUtc();
    final renewalTxs = _renewTreasuryPoolIfNeeded(sealedAt);
    final blockTxs = <PercTransaction>[
      ...renewalTxs,
      ..._treasuryEmissionTxs(sealedAt),
    ];
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
    _clearMicroblockLogForNextWard();

    return PercMicroblockRecordResult(
      recorded: true,
      blockSealed: true,
      microblockCount: 0,
      selfConsistent: true,
      blockIndex: blocks.last.index,
      wardAdvanced: true,
    );
  }

  static String _truncateLabel(String text, {int max = 72}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
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
    connectAllWalletsConcurrently();
    return acc;
  }

  /// One-time launch — only invoked when the seed treasury admin signs in on Render.
  void launchBlockchain() {
    if (blockchainLaunched) return;
    blockchainLaunched = true;
    _blockchainLaunchEventPending = true;
  }

  PercAccount login(String username, String password, {DateTime? now}) {
    final u = PercAuth.normalizeUsername(username);
    final acc = _accountFor(u);
    if (acc == null || !acc.passwordSet) throw StateError('Unknown account');
    if (!PercAuth.verifyPassword(
      password: password,
      salt: acc.salt,
      expectedHash: acc.passwordHash,
    )) {
      throw StateError('Invalid password');
    }
    sessionUsername = u;
    final t = (now ?? DateTime.now()).toUtc();
    sessionStartedAt = t;
    sessionLastActivityAt = t;
    refreshPendingInboundTransfers(now: t);
    return acc;
  }

  /// Reverts expired escrows and mirrors pending transfers for the session user.
  void refreshPendingInboundTransfers({DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    _revertExpiredPendingInbound(t);
    final u = sessionUsername;
    if (u != null) {
      _mirrorPendingInboundToTxList(u, t);
      _mirrorPendingOutboundToTxList(u);
    }
  }

  void _revertExpiredPendingInbound(DateTime now) {
    final window = PercChainConstants.walletInboundRevertWindowEffective;
    final expired = pendingInboundTransfers
        .where((p) => !now.isBefore(p.sentAt.add(window)))
        .toList();
    if (expired.isEmpty) return;

    final blockTxs = <PercTransaction>[];
    for (final pending in expired) {
      final sender = _accountFor(pending.fromUsername);
      final receiver = _resolvePendingRecipient(pending);
      pendingInboundTransfers.remove(pending);
      receiver?.transactions.removeWhere(
        (tx) => tx.id == pending.id && !tx.isConfirmed,
      );
      sender?.transactions.removeWhere(
        (tx) => tx.id == pending.id && !tx.isConfirmed,
      );
      if (sender == null) continue;

      final tx = PercTransaction(
        id: _newTxId(),
        kind: PercTxKind.transferRevert,
        amount: pending.amount,
        timestamp: now,
        fromUsername: pending.toUsername,
        toUsername: pending.fromUsername,
        memo:
            'Cancelled — ${pending.toUsername} did not confirm within ${_receiveWindowLabel(window)}',
        blockIndex: blocks.length,
        confirmations: _txConfirmations,
      );
      sender.transactions.insert(0, tx);
      blockTxs.add(tx);
    }

    if (blockTxs.isEmpty) return;
    _finalizeBlock(
      timestamp: now,
      blockTxs: blockTxs,
      treasuryEmitted: PercAmount.zero,
      triggerUsername: blockTxs.first.toUsername,
    );
  }

  String _receiveWindowLabel(Duration window) {
    if (window.inDays >= 7) return '${window.inDays} days';
    if (window.inDays >= 2) return '${window.inDays} days';
    if (window.inHours >= 1) return '${window.inHours} hours';
    return '${window.inSeconds} seconds';
  }

  bool _pendingTargetsUser(PercPendingInboundTransfer pending, String username) {
    if (pending.toUsername == username) return true;
    final receiver = _accountFor(username);
    if (receiver == null) return false;
    final alias = _accountFor(pending.toUsername);
    return alias != null && alias.address == receiver.address;
  }

  PercAccount? _resolvePendingRecipient(PercPendingInboundTransfer pending) {
    final direct = _accountFor(pending.toUsername);
    if (direct != null) return direct;
    for (final acc in accounts.values) {
      if (acc.passwordSet && _pendingTargetsUser(pending, acc.username)) {
        return acc;
      }
    }
    return null;
  }

  void _mirrorPendingInboundToTxList(String username, DateTime now) {
    for (final pending in pendingInboundTransfers) {
      if (!_pendingTargetsUser(pending, username)) continue;
      final receiver = _resolvePendingRecipient(pending);
      if (receiver == null) continue;
      _ensurePendingInboundTxListed(receiver, pending);
    }
  }

  void _mirrorPendingOutboundToTxList(String username) {
    final from = PercAuth.normalizeUsername(username);
    for (final pending in pendingInboundTransfers) {
      if (pending.fromUsername != from) continue;
      _ensurePendingOutboundTxListed(pending.fromUsername, pending);
    }
  }

  bool _canDebitSenderForPending(
    PercAccount sender,
    PercPendingInboundTransfer pending,
  ) =>
      sender.balance >= pending.totalHold;

  bool _attestSenderCanDebitOnPeer(
    PercLedger peer,
    PercPendingInboundTransfer pending,
  ) {
    final from = PercAuth.normalizeUsername(pending.fromUsername);
    final sender = peer.account(from);
    if (sender == null || !sender.passwordSet) return false;
    final holdActive = peer.pendingInboundTransfers.any(
      (p) => p.id == pending.id && p.fromUsername == from,
    );
    if (!holdActive) return false;
    return sender.balance >= pending.totalHold;
  }

  void _mergeSettlementWitnessesFromPeer(PercLedger remote) {
    final seen = settlementWitnesses.map((w) => w.transferId).toSet();
    for (final witness in remote.settlementWitnesses) {
      if (seen.contains(witness.transferId)) continue;
      settlementWitnesses.add(witness);
      seen.add(witness.transferId);
    }
  }

  bool _remoteWitnessPresent(PercLedger remote, String transferId) =>
      remote.settlementWitnesses.any(
        (w) => w.transferId == transferId && w.senderCanDebit,
      );

  /// Unified inbound relay: pending, tx lists, transfer blocks, witnesses.
  int applyInboundRelayFromSender(PercLedger remote) {
    final pendingBefore = pendingInboundTransfers.length;
    mergePendingInboundFromPeer(remote);
    mergeInboundTransferTxsFromPeer(remote);
    PercTransferRelayAck.acknowledgeRelayTransfers(this, remote);
    _mergeSettlementWitnessesFromPeer(remote);
    _trySettleEligiblePending(senderPeer: remote);
    final session = sessionUsername;
    if (session != null) {
      refreshPendingInboundTransfers();
    }
    return pendingInboundTransfers.length - pendingBefore;
  }

  bool _senderTransferConfirmed(String transferId, String fromUsername) {
    final sender = _accountFor(fromUsername);
    if (sender == null) return false;
    final tx = sender.transactions
        .where((t) => t.id == transferId && t.kind == PercTxKind.transfer);
    return tx.isNotEmpty && tx.first.isConfirmed;
  }

  Set<String> _confirmedTransferIdsOnLedger(PercLedger ledger) {
    final ids = <String>{};
    for (final block in ledger.blocks) {
      for (final tx in block.transactions) {
        if (tx.kind == PercTxKind.transfer && tx.isConfirmed) {
          ids.add(tx.id);
        }
      }
    }
    for (final acc in ledger.accounts.values) {
      for (final tx in acc.transactions) {
        if (tx.kind == PercTxKind.transfer && tx.isConfirmed) {
          ids.add(tx.id);
        }
      }
    }
    return ids;
  }

  /// When a peer has settled a transfer we initiated, debit the local sender,
  /// confirm the outbound tx, and release the outbound hold.
  void reconcileSettledTransfersFromPeer(PercLedger remote, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    final remotePendingIds =
        remote.pendingInboundTransfers.map((p) => p.id).toSet();
    final remoteSettledIds = _confirmedTransferIdsOnLedger(remote);

    for (final pending
        in List<PercPendingInboundTransfer>.from(pendingInboundTransfers)) {
      if (!isLocalOutboundHold(
        pending: pending,
        senderIsLocalWallet: _senderIsLocalWallet,
      )) {
        continue;
      }

      final hasWitness = _remoteWitnessPresent(remote, pending.id);
      final remoteSettled =
          remoteSettledIds.contains(pending.id) &&
              !remotePendingIds.contains(pending.id);
      if (!hasWitness && !remoteSettled) continue;

      final sender = _accountFor(pending.fromUsername);
      if (sender == null) continue;

      final plan = planSettlement(
        phase: SettlementPhase.senderPeerReconcile,
        senderIsLocalWallet: true,
        senderCanDebit: _canDebitSenderForPending(sender, pending),
        senderPeerProvided: true,
        remoteWitnessPresent: hasWitness,
        remoteSettledWithoutPending: remoteSettled,
      );
      if (!plan.shouldApply) continue;

      final blockTxs = <PercTransaction>[];
      if (plan.debitSender &&
          !_applySenderSettlement(pending, t, blockTxs: blockTxs)) {
        continue;
      }
      if (plan.removePending) {
        pendingInboundTransfers.remove(pending);
      }
      _finalizeBlock(
        timestamp: t,
        blockTxs: blockTxs,
        treasuryEmitted: PercAmount.zero,
        triggerUsername: pending.fromUsername,
      );
    }
  }

  /// Applies sender relay state so the recipient sees pending inbound txs
  /// immediately after a cross-device send is gossiped.
  void ingestInboundTransferInitiation(PercLedger remote) {
    applyInboundRelayFromSender(remote);
  }

  bool _applySenderSettlement(
    PercPendingInboundTransfer pending,
    DateTime t, {
    required List<PercTransaction> blockTxs,
  }) {
    final sender = _accountFor(pending.fromUsername);
    if (sender == null || !_canDebitSenderForPending(sender, pending)) {
      return false;
    }
    _debitForOutboundSettlement(sender, pending.totalHold);
    blockTxs.add(
      _burnTransactionFee(
        fee: pending.fee,
        fromUsername: pending.fromUsername,
        timestamp: t,
        sender: sender,
      ),
    );
    _replaceOrInsertTx(sender, _confirmedTransferTx(pending, t));
    return true;
  }

  void _ensurePendingInboundTxListed(
    PercAccount receiver,
    PercPendingInboundTransfer pending,
  ) {
    if (receiver.transactions.any((tx) => tx.id == pending.id)) return;
    receiver.transactions.insert(
      0,
      PercTransaction(
        id: pending.id,
        kind: PercTxKind.transfer,
        amount: pending.amount,
        timestamp: pending.sentAt,
        fromUsername: pending.fromUsername,
        toUsername: pending.toUsername,
        memo: pending.memo,
        blockIndex: _seedConfirmationBlockIndex(),
        confirmations: 0,
      ),
    );
  }

  void _ensurePendingOutboundTxListed(
    String fromUsername,
    PercPendingInboundTransfer pending,
  ) {
    final sender = _accountFor(fromUsername);
    if (sender == null) return;
    if (sender.transactions.any((tx) => tx.id == pending.id)) return;
    sender.transactions.insert(
      0,
      PercTransaction(
        id: pending.id,
        kind: PercTxKind.transfer,
        amount: pending.amount,
        timestamp: pending.sentAt,
        fromUsername: pending.fromUsername,
        toUsername: pending.toUsername,
        memo: pending.memo,
        blockIndex: _seedConfirmationBlockIndex(),
        confirmations: 0,
      ),
    );
  }

  PercTransaction _confirmedTransferTx(
    PercPendingInboundTransfer pending,
    DateTime timestamp, {
    int? blockIndex,
  }) =>
      PercTransaction(
        id: pending.id,
        kind: PercTxKind.transfer,
        amount: pending.amount,
        timestamp: timestamp,
        fromUsername: pending.fromUsername,
        toUsername: pending.toUsername,
        memo: pending.memo,
        blockIndex: blockIndex ?? blocks.length,
        confirmations: _txConfirmations,
      );

  /// Credits inbound PERC when send/relay/scenario activity can settle them.
  void settlePendingInboundOnActivity(
    String username, {
    PercLedger? senderPeer,
    PercSenderPeerResolver? senderPeerResolver,
    DateTime? now,
  }) {
    final t = (now ?? DateTime.now()).toUtc();
    _revertExpiredPendingInbound(t);
    final window = PercChainConstants.walletInboundRevertWindowEffective;
    final toSettle = pendingInboundTransfers
        .where((p) => _pendingTargetsUser(p, username))
        .where((p) => !t.isBefore(p.sentAt))
        .where((p) => t.isBefore(p.sentAt.add(window)))
        .toList();
    if (toSettle.isEmpty) return;

    final receiverAccount = _accountFor(username);
    final scenarioBlock = receiverAccount?.scenarioBlockHeight ?? 0;

    for (final pending in toSettle) {
      final receiver = _resolvePendingRecipient(pending);
      if (receiver == null) continue;

      final sender = _accountFor(pending.fromUsername);
      final senderIsLocal = _senderIsLocalWallet(pending.fromUsername);
      final resolvedPeer = senderIsLocal
          ? null
          : (senderPeer ?? senderPeerResolver?.call(pending.fromUsername));
      final senderCanDebit = senderIsLocal
          ? sender != null && _canDebitSenderForPending(sender, pending)
          : resolvedPeer != null &&
              _attestSenderCanDebitOnPeer(resolvedPeer, pending);

      final plan = planSettlement(
        phase: SettlementPhase.transferCredit,
        senderIsLocalWallet: senderIsLocal,
        senderCanDebit: senderCanDebit,
        senderPeerProvided: senderIsLocal || resolvedPeer != null,
        remoteWitnessPresent: false,
        remoteSettledWithoutPending: false,
      );
      if (!plan.shouldApply) continue;

      final confirmedTx = _confirmedTransferTx(pending, t);
      final blockTxs = <PercTransaction>[confirmedTx];

      if (plan.debitSender &&
          !_applySenderSettlement(pending, t, blockTxs: blockTxs)) {
        continue;
      }

      if (plan.creditReceiver) {
        _credit(receiver, pending.amount);
        _replaceOrInsertTx(receiver, confirmedTx);
      }

      if (plan.emitWitness) {
        settlementWitnesses.add(
          PercSettlementWitness(
            transferId: pending.id,
            receiverScenarioBlock: scenarioBlock,
            senderCanDebit: true,
            witnessedAt: t,
          ),
        );
      }

      if (plan.removePending) {
        pendingInboundTransfers.remove(pending);
      }

      _finalizeBlock(
        timestamp: t,
        blockTxs: blockTxs,
        treasuryEmitted: PercAmount.zero,
        triggerUsername: pending.toUsername,
      );
    }
  }

  void _trySettleEligiblePending({
    String? forUsername,
    PercLedger? senderPeer,
    DateTime? now,
  }) {
    final t = (now ?? DateTime.now()).toUtc();
    _revertExpiredPendingInbound(t);
    final targets = forUsername != null
        ? [forUsername]
        : pendingInboundTransfers.map((p) => p.toUsername).toSet().toList();
    final resolver = senderPeer != null
        ? (String from) =>
            senderPeer.account(from) != null ? senderPeer : null
        : null;
    for (final username in targets) {
      settlePendingInboundOnActivity(
        username,
        senderPeer: senderPeer,
        senderPeerResolver: resolver,
        now: t,
      );
    }
  }

  void _replaceOrInsertTx(PercAccount account, PercTransaction tx) {
    final existingIdx = account.transactions.indexWhere((t) => t.id == tx.id);
    if (existingIdx >= 0) {
      account.transactions[existingIdx] = tx;
    } else {
      account.transactions.insert(0, tx);
    }
  }

  void logout() {
    sessionUsername = null;
    sessionStartedAt = null;
    sessionLastActivityAt = null;
  }

  /// Mirrors pending inbound transfers into the signed-in user's transaction list.
  void refreshPendingInboundForSession({DateTime? now}) {
    refreshPendingInboundTransfers(now: now);
  }

  PercTransaction send({
    required String fromUsername,
    required String toAddress,
    required PercAmount amount,
    String? memo,
    bool? deliverInstantly,
    int? seedConfirmationBlockHeight,
  }) {
    if (!blockchainLaunched) {
      throw StateError(
        'Blockchain not launched — sync wallet to the internet seed node first',
      );
    }
    final from = PercAuth.normalizeUsername(fromUsername);
    final addrErr = PercAuth.validateAddress(toAddress);
    if (addrErr != null) throw StateError(addrErr);
    final toAddr = PercAuth.normalizeAddress(toAddress);
    if (!amount.isAtLeastSmallestUnit) {
      throw StateError(
        'Amount must be at least ${PercChainConstants.centValueInPerc} ${PercChainConstants.currencySymbol}',
      );
    }
    final sender = _accountFor(from);
    final receiver = _accountForAddress(toAddr);
    if (sender == null) {
      throw StateError('Sender account not found — sign in again');
    }
    if (receiver == null) {
      throw StateError(
        'Recipient address not found — they must register a wallet first',
      );
    }
    final to = receiver.username;
    if (sender.address == receiver.address) {
      throw StateError('Cannot send to yourself');
    }
    _assertTreasuryCanSend(from);
    final fee = PercChainConstants.sendTransactionFee;
    final totalDebit = amount + fee;
    if (_spendableBalance(sender) < totalDebit) {
      throw StateError(
        'Insufficient balance — need ${totalDebit.displayFixed8} ${PercChainConstants.currencySymbol} '
        '(${amount.displayFixed8} + ${fee.displayFixed8} network fee)',
      );
    }
    final now = DateTime.now().toUtc();
    _revertExpiredPendingInbound(now);
    final renewalTxs = _renewTreasuryPoolIfNeeded(now);
    final txId = _newTxId();
    final confirmBlockIndex = _seedConfirmationBlockIndex(
      seedConfirmationBlockHeight: seedConfirmationBlockHeight,
    );
    final pending = PercPendingInboundTransfer(
      id: txId,
      fromUsername: from,
      toUsername: to,
      amount: amount,
      fee: fee,
      sentAt: now,
      memo: memo,
      recipientBroughtOnlineAt:
          (deliverInstantly ?? isWalletOnlineOnNetwork(to)) ? now : null,
    );

    if (_isLocalSettleableRecipient(to)) {
      final blockTxs = <PercTransaction>[...renewalTxs];
      if (!_applySenderSettlement(pending, now, blockTxs: blockTxs)) {
        throw StateError(
          'Insufficient balance — need ${totalDebit.displayFixed8} ${PercChainConstants.currencySymbol} '
          '(${amount.displayFixed8} + ${fee.displayFixed8} network fee)',
        );
      }
      final confirmedTx = _confirmedTransferTx(
        pending,
        now,
        blockIndex: confirmBlockIndex,
      );
      blockTxs.add(confirmedTx);
      _credit(receiver, amount);
      _replaceOrInsertTx(receiver, confirmedTx);
      _finalizeBlock(
        timestamp: now,
        blockTxs: blockTxs,
        treasuryEmitted: PercAmount.zero,
        triggerUsername: from,
        isGenesisRenewal: renewalTxs.isNotEmpty,
      );
      return confirmedTx;
    }

    final tx = PercTransaction(
      id: txId,
      kind: PercTxKind.transfer,
      amount: amount,
      timestamp: now,
      fromUsername: from,
      toUsername: to,
      memo: memo,
      blockIndex: confirmBlockIndex,
      confirmations: 0,
    );
    sender.transactions.insert(0, tx);
    pendingInboundTransfers.add(pending);
    _ensurePendingInboundTxListed(receiver, pending);
    _ensurePendingOutboundTxListed(from, pending);

    final blockTxs = <PercTransaction>[...renewalTxs, tx];
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
    double? continuumScs,
    double? vortexScs,
    double? shearScs,
    double? resistanceScs,
    double? flowScs,
    PercSenderPeerResolver? senderPeerResolver,
  }) {
    final u = PercAuth.normalizeUsername(username);
    final user = _accountFor(u);
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
    final regenTxs = _regenerateTreasuryIfNeeded(now);
    final blockTxs = <PercTransaction>[...renewalTxs, ...regenTxs];
    var emitted = regenTxs.fold<PercAmount>(
      PercAmount.zero,
      (sum, tx) => sum + tx.amount,
    );
    final bootstrapEmission = _treasuryBootstrapEmission();
    if (bootstrapEmission.isPositive) {
      emitted = emitted + bootstrapEmission;
      treasuryGenesisDone = true;
      _appendTreasuryEmissionTx(
        amount: bootstrapEmission,
        now: now,
        treasury: treasury,
        blockTxs: blockTxs,
      );
    }
    final reward = PercFaucet.computeScenarioReward(percentChance: percentChance);
    PercFaucetReward? credited;

    if (cooldownLeft != null) {
      final accrualEmission = _treasuryAccrualEmissionForScenario(now);
      if (accrualEmission.isPositive) {
        emitted = emitted + accrualEmission;
        _appendTreasuryEmissionTx(
          amount: accrualEmission,
          now: now,
          treasury: treasury,
          blockTxs: blockTxs,
        );
      } else if (!treasuryGenesisDone) {
        treasuryGenesisDone = true;
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
        lastScenarioAt = now;
      }
      final scenarioBlock = advanceScenarioBlock(
        u,
        senderPeerResolver: senderPeerResolver,
      );
      return PercFaucetCreditResult(
        status: PercFaucetCreditStatus.onCooldown,
        cooldownRemaining: cooldownLeft,
        nextBlockEstimate: cooldownLeft,
        blockIndex: blocks.isEmpty ? null : blocks.last.index,
        scenarioBlockHeight: scenarioBlock,
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
        continuumScs: continuumScs,
        vortexScs: vortexScs,
        shearScs: shearScs,
        resistanceScs: resistanceScs,
        flowScs: flowScs,
      );
      treasury.transactions.insert(0, tx);
      user.transactions.insert(0, tx);
      blockTxs.add(tx);
      credited = reward;
    }

    final accrualEmission = _treasuryAccrualEmissionForScenario(now);
    if (accrualEmission.isPositive) {
      emitted = emitted + accrualEmission;
      _appendTreasuryEmissionTx(
        amount: accrualEmission,
        now: now,
        treasury: treasury,
        blockTxs: blockTxs,
      );
    } else if (!treasuryGenesisDone) {
      treasuryGenesisDone = true;
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
    final scenarioBlock = advanceScenarioBlock(
      u,
      senderPeerResolver: senderPeerResolver,
    );

    if (credited != null) {
      return PercFaucetCreditResult(
        status: PercFaucetCreditStatus.credited,
        reward: credited,
        blockIndex: blocks.isEmpty ? null : blocks.last.index,
        scenarioBlockHeight: scenarioBlock,
      );
    }

    return PercFaucetCreditResult(
      status: PercFaucetCreditStatus.treasuryEmpty,
      blockIndex: blocks.isEmpty ? null : blocks.last.index,
      scenarioBlockHeight: scenarioBlock,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 9,
        'evolutionaryChainId': evolutionaryChainId.isEmpty
            ? PercChainConstants.evolutionaryChainId
            : evolutionaryChainId,
        'chronofluxPrincipiaId': chronofluxPrincipiaId.isEmpty
            ? PercChainConstants.chronofluxPrincipiaId
            : chronofluxPrincipiaId,
        'mainChainId':
            mainChainId.isEmpty ? PercChainConstants.chainId : mainChainId,
        'sideChainId': sideChainId.isEmpty
            ? PercChainConstants.sideChainId
            : sideChainId,
        'connectedAppVersion':
            connectedAppVersion.isEmpty ? PercAppVersion.current : connectedAppVersion,
        'evolvedAppVersions': evolvedAppVersions,
        'evolutionSteps': evolutionSteps.map((e) => e.toJson()).toList(),
        'evolutionEpoch': evolutionEpoch,
        'networkGenesisRevision': networkGenesisRevision,
        'accounts': accounts.map((k, v) => MapEntry(k, v.toJson())),
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'lastScenarioAt': lastScenarioAt?.toIso8601String(),
        'treasuryGenesisDone': treasuryGenesisDone,
        'cumulativeTreasuryMinted': cumulativeTreasuryMinted.toJson(),
        'cumulativeBurnedPerc': cumulativeBurnedPerc.toJson(),
        'treasuryCycle': treasuryCycle,
        'blockchainLaunched': blockchainLaunched,
        'sessionUsername': sessionUsername,
        if (sessionStartedAt != null)
          'sessionStartedAt': sessionStartedAt!.toIso8601String(),
        if (sessionLastActivityAt != null)
          'sessionLastActivityAt': sessionLastActivityAt!.toIso8601String(),
        'nextTxId': nextTxId,
        'microblockCount': microblockCount,
        'totalMicroblocks': totalMicroblocks,
        if (lastChronofluxFingerprint != null)
          'lastChronofluxFingerprint': lastChronofluxFingerprint,
        'walletPeers': walletPeers.map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        ),
        'networkNodes': networkNodes.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
        'wardProposals': wardProposals.map((p) => p.toJson()).toList(),
        'wardBallots': wardBallots.map((b) => b.toJson()).toList(),
        'nextWardProposalId': nextWardProposalId,
        'pendingInboundTransfers':
            pendingInboundTransfers.map((p) => p.toJson()).toList(),
        'settlementWitnesses':
            settlementWitnesses.map((w) => w.toJson()).toList(),
        'microblockLog': microblockLog.map((e) => e.toJson()).toList(),
      };

  factory PercLedger.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('chainId')) {
      return _migrateFromChainService(json);
    }
    final version = json['version'] as int? ?? 1;
    if (version < 2) return _migrateFromV1(json);
    if (version < 9) return _migrateToV9(json);

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
      cumulativeBurnedPerc: json['cumulativeBurnedPerc'] != null
          ? PercAmount.fromJson(
              json['cumulativeBurnedPerc'] as Map<String, dynamic>)
          : PercAmount.zero,
      treasuryCycle: json['treasuryCycle'] as int? ?? 1,
      blockchainLaunched: json['blockchainLaunched'] as bool? ??
          (blocks.isNotEmpty || treasuryGenesisDone),
      sessionUsername: json['sessionUsername'] as String?,
      sessionStartedAt: json['sessionStartedAt'] != null
          ? DateTime.parse(json['sessionStartedAt'] as String)
          : null,
      sessionLastActivityAt: json['sessionLastActivityAt'] != null
          ? DateTime.parse(json['sessionLastActivityAt'] as String)
          : null,
      nextTxId: json['nextTxId'] as int? ?? 1,
      microblockCount: json['microblockCount'] as int? ?? 0,
      totalMicroblocks: json['totalMicroblocks'] as int? ?? 0,
      lastChronofluxFingerprint: json['lastChronofluxFingerprint'] as String?,
      walletPeers: _walletPeersFromJson(json['walletPeers']),
      networkNodes: _networkNodesFromJson(json['networkNodes']),
      evolutionaryChainId: json['evolutionaryChainId'] as String? ?? '',
      chronofluxPrincipiaId: json['chronofluxPrincipiaId'] as String? ?? '',
      mainChainId: json['mainChainId'] as String? ?? '',
      sideChainId: json['sideChainId'] as String? ?? '',
      connectedAppVersion: json['connectedAppVersion'] as String? ?? '',
      evolvedAppVersions: (json['evolvedAppVersions'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      evolutionSteps: (json['evolutionSteps'] as List<dynamic>? ?? [])
          .map((e) => PercEvolutionStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      evolutionEpoch: json['evolutionEpoch'] as int? ?? 1,
      networkGenesisRevision: json['networkGenesisRevision'] as int? ?? 1,
      wardProposals: (json['wardProposals'] as List<dynamic>? ?? [])
          .map((e) => WardProposal.fromJson(e as Map<String, dynamic>))
          .toList(),
      wardBallots: (json['wardBallots'] as List<dynamic>? ?? [])
          .map((e) => WardBallot.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextWardProposalId: json['nextWardProposalId'] as int? ?? 1,
      pendingInboundTransfers:
          (json['pendingInboundTransfers'] as List<dynamic>? ?? [])
              .map(
                (e) => PercPendingInboundTransfer.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      settlementWitnesses:
          (json['settlementWitnesses'] as List<dynamic>? ?? [])
              .map(
                (e) => PercSettlementWitness.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      microblockLog: (json['microblockLog'] as List<dynamic>? ?? [])
          .map(
            (e) => PercMicroblockLogEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    )..repairForAppUpgrade();
  }

  static Map<String, List<String>> _walletPeersFromJson(Object? raw) {
    if (raw is! Map) return {};
    final mesh = <String, List<String>>{};
    for (final entry in raw.entries) {
      final peers = entry.value;
      if (peers is List) {
        mesh[entry.key as String] =
            peers.map((e) => e as String).toList()..sort();
      }
    }
    return mesh;
  }

  static Map<String, PercPeerNode> _networkNodesFromJson(Object? raw) {
    if (raw is! Map) return {};
    final nodes = <String, PercPeerNode>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is Map) {
        nodes[entry.key as String] =
            PercPeerNode.fromJson(Map<String, dynamic>.from(value));
      }
    }
    return nodes;
  }

  static PercLedger _migrateToV9(Map<String, dynamic> json) {
    final migrated = Map<String, dynamic>.from(json)..['version'] = 9;
    final walletPeers = _walletPeersFromJson(json['walletPeers']);
    final blocks = (json['blocks'] as List<dynamic>? ?? [])
        .map((e) => PercBlock.fromJson(e as Map<String, dynamic>))
        .toList();
    final height = blocks.length;
    final tip = height == 0
        ? PercChainTip.hash(
            PercLedger(
              accounts: {},
              blocks: [],
              lastScenarioAt: null,
              treasuryGenesisDone: false,
              cumulativeTreasuryMinted: PercAmount.zero,
            ),
          )
        : PercChainTip.hash(
            PercLedger(
              accounts: {},
              blocks: blocks,
              lastScenarioAt: null,
              treasuryGenesisDone: false,
              cumulativeTreasuryMinted: PercAmount.zero,
            ),
          );
    final nodes = <String, PercPeerNode>{};
    for (final username in walletPeers.keys) {
      nodes[username] = PercPeerNode.offline(
        username: username,
        blockHeight: height,
        tipHash: tip,
      );
    }
    migrated['networkNodes'] = nodes.map((k, v) => MapEntry(k, v.toJson()));
    return PercLedger.fromJson(migrated);
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