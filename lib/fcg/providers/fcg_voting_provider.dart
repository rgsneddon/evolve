import 'package:flutter/foundation.dart';

import '../../models/analysis_mode.dart';
import '../../models/evolve_result.dart';
import '../../models/locale_config.dart';
import '../../models/scenario_input.dart';
import '../../perc/services/perc_auth.dart';
import '../models/fcg_audit_log.dart';
import '../models/fcg_models.dart';
import '../services/fcg_moderator.dart';
import '../services/fcg_policy_analyzer.dart';
import '../services/fcg_quorum_engine.dart';
import '../services/fcg_results_exporter.dart';
import '../mishi/fcg_mishi_bridge_store.dart';
import '../mishi/fcg_mishi_directive.dart';
import '../mishi/fcg_mishi_permission.dart';
import '../services/fcg_store.dart';
import '../services/fcg_store_factory.dart';

class FcgVotingProvider extends ChangeNotifier {
  FcgVotingProvider({
    FcgStore? store,
    FcgPolicyAnalyzer? analyzer,
    FcgQuorumEngine? quorumEngine,
    FcgResultsExporter? exporter,
    FcgMishiBridgeStore? mishiBridge,
  })  : _store = store ?? createFcgStore(),
        _analyzer = analyzer ?? const FcgPolicyAnalyzer(),
        _quorum = quorumEngine ?? const FcgQuorumEngine(),
        _exporter = exporter ?? const FcgResultsExporter(),
        _mishiBridge = mishiBridge ?? FcgMishiBridgeStore();

  static const int scenarioRunCap = 200;

  final FcgStore _store;
  final FcgPolicyAnalyzer _analyzer;
  final FcgQuorumEngine _quorum;
  final FcgResultsExporter _exporter;
  final FcgMishiBridgeStore _mishiBridge;
  int _idSeq = 0;

  bool _votingAccessApproved = false;
  FcgMishiPermissionStatus? _votingAccessStatus;

  FcgWardDatabase _db = const FcgWardDatabase();
  bool _ready = false;
  bool _busy = false;
  String? _statusMessage;
  String? _errorMessage;

  bool get ready => _ready;
  bool get busy => _busy;
  bool get votingAccessApproved => _votingAccessApproved;
  FcgMishiPermissionStatus? get votingAccessStatus => _votingAccessStatus;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  List<FcgScenarioRun> get scenarioRuns =>
      List.unmodifiable(_db.scenarioRuns);

  List<FcgVotingSession> get sessions => List.unmodifiable(_db.sessions);

  FcgVotingSession? get activeSession => _db.activeSession;

  FcgQuorumSnapshot? get activeQuorumSnapshot =>
      activeSession?.quorumSnapshot;

  Future<void> initialize() async {
    final loaded = await _store.load();
    _db = loaded ?? const FcgWardDatabase();
    _ready = true;
    notifyListeners();
  }

  List<FcgScenarioRun> scenarioRunsForRegion(String regionId) {
    return _db.scenarioRuns
        .where((r) => r.regionId == regionId)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  List<FcgScenarioRun> cohesionNarrativesForRegion(String regionId) {
    return scenarioRunsForRegion(regionId)
        .where((r) => r.narrativeExcerpt.isNotEmpty)
        .toList();
  }

  bool isModerator(String? walletUsername) =>
      FcgModerator.isModeratorUsername(walletUsername);

  String moderatorUsernameForRegion(String regionId) =>
      FcgModerator.usernameForRegion(regionId);

  FcgVoterSlot? slotForWalletAddress(String? address) {
    if (address == null || address.trim().isEmpty) return null;
    return activeSession?.slotForAddress(address);
  }

  /// Moderators always pass; voters need Mishi-approved permission this month.
  Future<bool> refreshVotingAccess({
    required String? walletAddress,
    required String? walletUsername,
    required String regionId,
    LocaleConfig locale = LocaleConfig.defaults,
  }) async {
    if (isModerator(walletUsername)) {
      await applyMishiDirectives(
        moderatorUsername: walletUsername!,
        regionId: regionId,
        locale: locale,
      );
      _votingAccessApproved = true;
      _votingAccessStatus = FcgMishiPermissionStatus.approved;
      notifyListeners();
      return true;
    }
    if (walletAddress == null || walletAddress.trim().isEmpty) {
      _votingAccessApproved = false;
      _votingAccessStatus = null;
      notifyListeners();
      return false;
    }
    final perm = await _mishiBridge.permissionForAddress(
      percAddress: walletAddress,
      forumMonth: fcgMishiForumMonth(),
    );
    _votingAccessStatus = perm?.status;
    _votingAccessApproved = perm?.isApproved ?? false;
    notifyListeners();
    return _votingAccessApproved;
  }

  Future<FcgMishiPermissionStatus> requestVotingAccess({
    required String walletAddress,
    required String walletUsername,
    required String regionId,
  }) async {
    final modUsername = moderatorUsernameForRegion(regionId);
    final wardLabel = FcgModerator.regionLabel(regionId);
    final permission = await _mishiBridge.requestVotingAccess(
      percAddress: walletAddress,
      walletUsername: walletUsername,
      moderatorUsername: modUsername,
      wardLabel: wardLabel,
    );
    _votingAccessStatus = permission.status;
    _votingAccessApproved = permission.isApproved;
    _statusMessage = 'fcg_voting_access_requested';
    notifyListeners();
    return permission.status;
  }

  bool canWalletVote(String? address) {
    final session = activeSession;
    if (session == null || session.status != FcgSessionStatus.active) {
      return false;
    }
    final slot = slotForWalletAddress(address);
    return slot != null && slot.isEnrolled;
  }

  FcgQuorumSnapshot quorumFor(FcgVotingSession session) =>
      _quorum.evaluate(
        session,
        quorumPercent: session.quorumThresholdPercent,
      );

  String exportResultsMarkdown({
    required FcgVotingSession session,
    required String regionLabel,
  }) =>
      _exporter.buildMarkdown(
        session: session,
        auditLog: session.auditLog,
        regionLabel: regionLabel,
        quorumPercent: session.quorumThresholdPercent,
      );

  String exportResultsJson({
    required FcgVotingSession session,
    required String regionLabel,
  }) =>
      _exporter.buildJsonString(
        session: session,
        auditLog: session.auditLog,
        regionLabel: regionLabel,
        quorumPercent: session.quorumThresholdPercent,
      );

  Future<void> recordScenarioRun({
    required ScenarioInput input,
    required LocaleConfig locale,
    required AnalysisMode mode,
    required EvolveResult result,
  }) async {
    if (!_ready) return;
    final question = input.posedQuestion.trim().isNotEmpty
        ? input.posedQuestion.trim()
        : input.topic.trim();
    if (question.isEmpty) return;

    final run = FcgScenarioRun(
      id: _newId('run'),
      recordedAt: DateTime.now().toUtc(),
      posedQuestion: question,
      regionId: locale.regionId,
      mode: mode,
      cohesionReport: result.cohesionReport,
      percentChance: result.percentChance,
      refinedScs: result.core.refinedScs,
      continuumConclusion: result.continuumConclusion,
      percentPhrase: result.percentPhrase,
    );

    final runs = [run, ..._db.scenarioRuns];
    if (runs.length > scenarioRunCap) {
      runs.removeRange(scenarioRunCap, runs.length);
    }
    _db = _db.copyWith(scenarioRuns: runs);
    await _persist();
  }

  Future<FcgVotingSession?> initiateSession({
    required String moderatorUsername,
    required String regionId,
    required String policyQuestion,
    required bool runCohesion,
    required bool runPercent,
    required LocaleConfig locale,
  }) async {
    if (!_ready || _busy) return null;
    if (!isModerator(moderatorUsername)) {
      _errorMessage = 'moderator_required';
      notifyListeners();
      return null;
    }
    final question = policyQuestion.trim();
    if (question.isEmpty) {
      _errorMessage = 'policy_question_required';
      notifyListeners();
      return null;
    }
    if (!runCohesion && !runPercent) {
      _errorMessage = 'analysis_mode_required';
      notifyListeners();
      return null;
    }

    _busy = true;
    _errorMessage = null;
    _statusMessage = 'fcg_analyzing_policy';
    notifyListeners();

    try {
      final analysis = _analyzer.analyze(
        policyQuestion: question,
        locale: locale,
        runCohesion: runCohesion,
        runPercent: runPercent,
      );

      var session = FcgVotingSession(
        id: _newId('session'),
        regionId: regionId,
        policyQuestion: question,
        moderatorUsername: moderatorUsername.trim(),
        createdAt: DateTime.now().toUtc(),
        status: FcgSessionStatus.active,
        runCohesion: runCohesion,
        runPercent: runPercent,
        cohesionScs: analysis.cohesionScs,
        percentChance: analysis.percentChance,
        cohesionNarrative: analysis.cohesionNarrative,
        percentNarrative: analysis.percentNarrative,
        slots: FcgWardDatabase.seedSlots(),
      );

      session = _withAudit(
        session,
        action: FcgAuditAction.sessionOpened,
        actor: moderatorUsername.trim(),
        detail: question,
      );

      final sessions = [..._db.sessions, session];
      _db = _db.copyWith(
        sessions: sessions,
        activeSessionId: session.id,
      );
      await _persist();
      _statusMessage = 'fcg_session_started';
      return session;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> linkNarrativeToSession(String scenarioRunId) async {
    final session = activeSession;
    if (session == null) return;
    final run = _findRun(scenarioRunId);
    if (run == null) return;

    var updated = session.copyWith(
      linkedScenarioRunId: scenarioRunId,
      cohesionNarrative: run.narrativeExcerpt.isNotEmpty
          ? run.narrativeExcerpt
          : session.cohesionNarrative,
    );
    updated = _withAudit(
      updated,
      action: FcgAuditAction.narrativeLinked,
      actor: session.moderatorUsername,
      detail: run.posedQuestion,
    );
    await _replaceSession(updated);
    _statusMessage = 'fcg_narrative_linked';
    notifyListeners();
  }

  Future<bool> commitSlotAddress({
    required int slotNumber,
    required String percAddress,
    required String moderatorUsername,
  }) async {
    return _enrollAddress(
      slotNumber: slotNumber,
      percAddress: percAddress,
      moderatorUsername: moderatorUsername,
      reEnrollment: false,
    );
  }

  Future<bool> reEnrollSlotAddress({
    required int slotNumber,
    required String percAddress,
    required String moderatorUsername,
  }) async {
    return _enrollAddress(
      slotNumber: slotNumber,
      percAddress: percAddress,
      moderatorUsername: moderatorUsername,
      reEnrollment: true,
    );
  }

  Future<bool> _enrollAddress({
    required int slotNumber,
    required String percAddress,
    required String moderatorUsername,
    required bool reEnrollment,
  }) async {
    final session = activeSession;
    if (session == null) return false;
    if (!isModerator(moderatorUsername)) {
      _errorMessage = 'moderator_required';
      notifyListeners();
      return false;
    }
    if (slotNumber < 1 || slotNumber > FcgWardDatabase.slotCount) {
      _errorMessage = 'fcg_invalid_slot';
      notifyListeners();
      return false;
    }

    final target = session.slotByNumber(slotNumber);
    if (target == null) return false;
    if (target.isEnrolled) {
      _errorMessage = 'fcg_slot_already_enrolled';
      notifyListeners();
      return false;
    }

    final normalized = PercAuth.normalizeAddress(percAddress);
    final validation = PercAuth.validateAddress(normalized);
    if (validation != null) {
      _errorMessage = 'fcg_invalid_perc_address';
      notifyListeners();
      return false;
    }

    for (final existing in session.slots) {
      if (existing.slot == slotNumber) continue;
      if (existing.isEnrolled &&
          PercAuth.normalizeAddress(existing.percAddress!) == normalized) {
        _errorMessage = 'fcg_address_already_enrolled';
        notifyListeners();
        return false;
      }
    }

    final wasReleased = session.auditLog.slotHasEnrollmentHistory(slotNumber);
    final action = reEnrollment || wasReleased
        ? FcgAuditAction.addressReEnrolled
        : FcgAuditAction.addressCommitted;

    final slots = session.slots.map((slot) {
      if (slot.slot != slotNumber) return slot;
      return slot.copyWith(
        percAddress: normalized,
        committedAt: DateTime.now().toUtc(),
        clearVote: true,
        clearLinkedScenarioRunId: true,
        rationale: '',
      );
    }).toList();

    var updated = session.copyWith(slots: slots);
    updated = _withAudit(
      updated,
      action: action,
      actor: moderatorUsername.trim(),
      slotNumber: slotNumber,
      percAddress: normalized,
      detail: action == FcgAuditAction.addressReEnrolled
          ? 're-enrollment'
          : 'initial commit',
    );

    await _replaceSession(updated);
    _errorMessage = null;
    _statusMessage = action == FcgAuditAction.addressReEnrolled
        ? 'fcg_address_reenrolled'
        : 'fcg_address_committed';
    notifyListeners();
    return true;
  }

  Future<void> clearSlotAddress({
    required int slotNumber,
    required String moderatorUsername,
  }) async {
    await _freeSlot(
      slotNumber: slotNumber,
      moderatorUsername: moderatorUsername,
      action: FcgAuditAction.addressCleared,
      statusKey: 'fcg_address_cleared',
    );
  }

  Future<void> releaseSlot({
    required int slotNumber,
    required String moderatorUsername,
    String? reason,
  }) async {
    await _freeSlot(
      slotNumber: slotNumber,
      moderatorUsername: moderatorUsername,
      action: FcgAuditAction.slotReleased,
      statusKey: 'fcg_slot_released',
      detail: reason?.trim().isNotEmpty == true ? reason!.trim() : 'released',
    );
  }

  Future<void> _freeSlot({
    required int slotNumber,
    required String moderatorUsername,
    required FcgAuditAction action,
    required String statusKey,
    String? detail,
  }) async {
    final session = activeSession;
    if (session == null || !isModerator(moderatorUsername)) return;
    if (slotNumber < 1 || slotNumber > FcgWardDatabase.slotCount) return;

    final current = session.slotByNumber(slotNumber);
    final releasedAddress = current?.percAddress;

    final slots = session.slots.map((slot) {
      if (slot.slot != slotNumber) return slot;
      return slot.copyWith(
        clearPercAddress: true,
        clearVote: true,
        clearLinkedScenarioRunId: true,
        clearCommittedAt: true,
        rationale: '',
      );
    }).toList();

    var updated = session.copyWith(slots: slots);
    updated = _withAudit(
      updated,
      action: action,
      actor: moderatorUsername.trim(),
      slotNumber: slotNumber,
      percAddress: releasedAddress,
      detail: detail,
    );

    await _replaceSession(updated);
    _statusMessage = statusKey;
    notifyListeners();
  }

  Future<bool> castUserVote({
    required String walletAddress,
    required FcgVoteChoice vote,
    String? linkedScenarioRunId,
    String? rationale,
  }) async {
    final session = activeSession;
    if (session == null || session.status != FcgSessionStatus.active) {
      _errorMessage = 'fcg_no_active_vote';
      notifyListeners();
      return false;
    }

    final enrolled = session.slotForAddress(walletAddress);
    if (enrolled == null) {
      _errorMessage = 'fcg_wallet_not_enrolled';
      notifyListeners();
      return false;
    }

    final priorVote = enrolled.vote;
    final action = priorVote == null
        ? FcgAuditAction.voteCast
        : FcgAuditAction.voteChanged;

    final slots = session.slots.map((slot) {
      if (!slot.matchesAddress(walletAddress)) return slot;
      return slot.copyWith(
        vote: vote,
        linkedScenarioRunId: linkedScenarioRunId,
        rationale: rationale?.trim() ?? slot.rationale,
      );
    }).toList();

    var updated = session.copyWith(slots: slots);
    updated = _withAudit(
      updated,
      action: action,
      actor: _maskAddress(walletAddress),
      slotNumber: enrolled.slot,
      percAddress: walletAddress,
      vote: vote,
      detail: priorVote?.name,
    );

    await _replaceSession(updated);
    _errorMessage = null;
    _statusMessage = 'fcg_vote_recorded';
    notifyListeners();
    return true;
  }

  Future<void> amendActiveSession({
    required String policyQuestion,
    required String moderatorUsername,
  }) async {
    final session = activeSession;
    if (session == null) return;
    if (!isModerator(moderatorUsername)) return;
    final question = policyQuestion.trim();
    if (question.isEmpty) return;

    var updated = session.copyWith(policyQuestion: question);
    updated = _withAudit(
      updated,
      action: FcgAuditAction.sessionOpened,
      actor: moderatorUsername.trim(),
      detail: 'amended: $question',
    );
    await _replaceSession(updated);
    _statusMessage = 'fcg_session_amended';
    notifyListeners();
  }

  Future<void> applyMishiDirectives({
    required String moderatorUsername,
    required String regionId,
    LocaleConfig locale = LocaleConfig.defaults,
  }) async {
    if (!isModerator(moderatorUsername)) return;
    final directives = await _mishiBridge.takeDirectivesForModerator(
      moderatorUsername,
    );
    for (final d in directives) {
      if (d.regionId != regionId && d.regionId != 'global') continue;
      switch (d.kind) {
        case FcgMishiDirectiveKind.openVote:
          await initiateSession(
            moderatorUsername: moderatorUsername,
            regionId: d.regionId,
            policyQuestion: d.policyQuestion,
            runCohesion: d.runCohesion,
            runPercent: d.runPercent,
            locale: locale.copyWith(regionId: d.regionId),
          );
        case FcgMishiDirectiveKind.closeVote:
        case FcgMishiDirectiveKind.concludeDebate:
          await closeActiveSession();
        case FcgMishiDirectiveKind.amendVote:
          await amendActiveSession(
            policyQuestion: d.policyQuestion,
            moderatorUsername: moderatorUsername,
          );
        case FcgMishiDirectiveKind.startDebate:
          final session = activeSession;
          if (session == null) {
            await initiateSession(
              moderatorUsername: moderatorUsername,
              regionId: d.regionId,
              policyQuestion: d.policyQuestion.isNotEmpty
                  ? d.policyQuestion
                  : 'Parish policy debate',
              runCohesion: d.runCohesion,
              runPercent: d.runPercent,
              locale: locale.copyWith(regionId: d.regionId),
            );
          }
      }
    }
  }

  Future<void> closeActiveSession() async {
    final session = activeSession;
    if (session == null) return;

    var updated = session.copyWith(status: FcgSessionStatus.closed);
    updated = _withAudit(
      updated,
      action: FcgAuditAction.sessionClosed,
      actor: session.moderatorUsername,
      detail: updated.quorumSnapshot.outcome.name,
    );

    await _replaceSession(updated);
    _db = _db.copyWith(clearActiveSessionId: true);
    await _persist();
    _statusMessage = 'fcg_session_closed';
    notifyListeners();
  }

  void clearMessages() {
    _statusMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  FcgScenarioRun? _findRun(String id) {
    for (final run in _db.scenarioRuns) {
      if (run.id == id) return run;
    }
    return null;
  }

  FcgVotingSession _withAudit(
    FcgVotingSession session, {
    required FcgAuditAction action,
    required String actor,
    int? slotNumber,
    String? percAddress,
    FcgVoteChoice? vote,
    String? detail,
  }) {
    final entry = FcgAuditEntry(
      id: _newId('audit'),
      timestamp: DateTime.now().toUtc(),
      action: action,
      actor: actor,
      slotNumber: slotNumber,
      percAddress: percAddress == null ? null : _maskAddress(percAddress),
      voteName: vote?.name,
      detail: detail,
      prevHash: session.auditLog.tipHash,
    );
    return session.copyWith(auditLog: session.auditLog.append(entry));
  }

  String _maskAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 10)}…${address.substring(address.length - 6)}';
  }

  Future<void> _replaceSession(FcgVotingSession updated) async {
    final sessions = _db.sessions
        .map((s) => s.id == updated.id ? updated : s)
        .toList(growable: false);
    _db = _db.copyWith(sessions: sessions);
    await _persist();
  }

  Future<void> _persist() async {
    await _store.save(_db);
    notifyListeners();
  }

  String _newId(String prefix) {
    _idSeq++;
    final ms = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'fcg-$prefix-$ms-$_idSeq';
  }
}