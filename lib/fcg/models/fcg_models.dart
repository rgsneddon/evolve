import '../../models/analysis_mode.dart';
import '../../perc/services/perc_auth.dart';
import 'fcg_audit_log.dart';
import '../services/fcg_quorum_engine.dart';

/// Parish council vote choice — each enrolled voter has one vote power.
enum FcgVoteChoice {
  support,
  oppose,
  abstain,
}

extension FcgVoteChoiceJson on FcgVoteChoice {
  String toJson() => name;

  static FcgVoteChoice? fromJson(String? raw) {
    if (raw == null) return null;
    return FcgVoteChoice.values.asNameMap()[raw];
  }
}

/// Recorded analysis run from the Analysis tab — feeds cohesion narratives.
class FcgScenarioRun {
  const FcgScenarioRun({
    required this.id,
    required this.recordedAt,
    required this.posedQuestion,
    required this.regionId,
    required this.mode,
    this.cohesionReport = '',
    this.percentChance,
    this.refinedScs,
    this.continuumConclusion = '',
    this.percentPhrase = '',
  });

  final String id;
  final DateTime recordedAt;
  final String posedQuestion;
  final String regionId;
  final AnalysisMode mode;
  final String cohesionReport;
  final double? percentChance;
  final double? refinedScs;
  final String continuumConclusion;
  final String percentPhrase;

  String get narrativeExcerpt {
    if (mode == AnalysisMode.cohesionScore && cohesionReport.trim().isNotEmpty) {
      return cohesionReport.trim();
    }
    if (continuumConclusion.trim().isNotEmpty) return continuumConclusion.trim();
    if (percentPhrase.trim().isNotEmpty) return percentPhrase.trim();
    return posedQuestion.trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'posedQuestion': posedQuestion,
        'regionId': regionId,
        'mode': mode.name,
        'cohesionReport': cohesionReport,
        if (percentChance != null) 'percentChance': percentChance,
        if (refinedScs != null) 'refinedScs': refinedScs,
        'continuumConclusion': continuumConclusion,
        'percentPhrase': percentPhrase,
      };

  factory FcgScenarioRun.fromJson(Map<String, dynamic> json) => FcgScenarioRun(
        id: json['id'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String).toUtc(),
        posedQuestion: json['posedQuestion'] as String? ?? '',
        regionId: json['regionId'] as String? ?? 'global',
        mode: AnalysisMode.values.asNameMap()[json['mode'] as String? ?? ''] ??
            AnalysisMode.cohesionScore,
        cohesionReport: json['cohesionReport'] as String? ?? '',
        percentChance: (json['percentChance'] as num?)?.toDouble(),
        refinedScs: (json['refinedScs'] as num?)?.toDouble(),
        continuumConclusion: json['continuumConclusion'] as String? ?? '',
        percentPhrase: json['percentPhrase'] as String? ?? '',
      );
}

/// One of 30 parish voter slots — MOD commits a PERC address; that wallet may vote once.
class FcgVoterSlot {
  const FcgVoterSlot({
    required this.slot,
    this.percAddress,
    this.vote,
    this.rationale = '',
    this.linkedScenarioRunId,
    this.committedAt,
  });

  final int slot;
  final String? percAddress;
  final FcgVoteChoice? vote;
  final String rationale;
  final String? linkedScenarioRunId;
  final DateTime? committedAt;

  bool get isEnrolled =>
      percAddress != null && percAddress!.trim().isNotEmpty;

  bool get hasVoted => vote != null;

  String get slotLabel => slot.toString().padLeft(2, '0');

  bool matchesAddress(String address) {
    if (!isEnrolled) return false;
    return PercAuth.normalizeAddress(percAddress!) ==
        PercAuth.normalizeAddress(address);
  }

  FcgVoterSlot copyWith({
    int? slot,
    String? percAddress,
    bool clearPercAddress = false,
    FcgVoteChoice? vote,
    bool clearVote = false,
    String? rationale,
    String? linkedScenarioRunId,
    bool clearLinkedScenarioRunId = false,
    DateTime? committedAt,
    bool clearCommittedAt = false,
  }) =>
      FcgVoterSlot(
        slot: slot ?? this.slot,
        percAddress:
            clearPercAddress ? null : (percAddress ?? this.percAddress),
        vote: clearVote ? null : (vote ?? this.vote),
        rationale: rationale ?? this.rationale,
        linkedScenarioRunId: clearLinkedScenarioRunId
            ? null
            : (linkedScenarioRunId ?? this.linkedScenarioRunId),
        committedAt:
            clearCommittedAt ? null : (committedAt ?? this.committedAt),
      );

  Map<String, dynamic> toJson() => {
        'slot': slot,
        if (percAddress != null) 'percAddress': percAddress,
        if (vote != null) 'vote': vote!.toJson(),
        'rationale': rationale,
        if (linkedScenarioRunId != null)
          'linkedScenarioRunId': linkedScenarioRunId,
        if (committedAt != null)
          'committedAt': committedAt!.toUtc().toIso8601String(),
      };

  factory FcgVoterSlot.fromJson(Map<String, dynamic> json) => FcgVoterSlot(
        slot: _slotFromJson(json),
        percAddress: json['percAddress'] as String?,
        vote: FcgVoteChoiceJson.fromJson(json['vote'] as String?),
        rationale: json['rationale'] as String? ?? '',
        linkedScenarioRunId: json['linkedScenarioRunId'] as String?,
        committedAt: json['committedAt'] == null
            ? null
            : DateTime.parse(json['committedAt'] as String).toUtc(),
      );

  static int _slotFromJson(Map<String, dynamic> json) {
    final rawSlot = json['slot'];
    if (rawSlot is int && rawSlot >= 1 && rawSlot <= FcgWardDatabase.slotCount) {
      return rawSlot;
    }
    final legacyId = json['id'] as String? ?? '';
    final match = RegExp(r'VOTER_(\d+)').firstMatch(legacyId);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 1;
  }
}

enum FcgSessionStatus { draft, active, closed }

/// Ward parish council vote session initiated by a MOD_* moderator.
class FcgVotingSession {
  const FcgVotingSession({
    required this.id,
    required this.regionId,
    required this.policyQuestion,
    required this.moderatorUsername,
    required this.createdAt,
    this.status = FcgSessionStatus.draft,
    this.runCohesion = true,
    this.runPercent = true,
    this.cohesionScs,
    this.percentChance,
    this.cohesionNarrative = '',
    this.percentNarrative = '',
    this.linkedScenarioRunId,
    this.slots = const [],
    this.auditLog = const FcgAuditLog(),
    this.quorumThresholdPercent = FcgQuorumEngine.defaultQuorumPercent,
  });

  final String id;
  final String regionId;
  final String policyQuestion;
  final String moderatorUsername;
  final DateTime createdAt;
  final FcgSessionStatus status;
  final bool runCohesion;
  final bool runPercent;
  final double? cohesionScs;
  final double? percentChance;
  final String cohesionNarrative;
  final String percentNarrative;
  final String? linkedScenarioRunId;
  final List<FcgVoterSlot> slots;
  final FcgAuditLog auditLog;
  final double quorumThresholdPercent;

  int get enrolledCount => slots.where((s) => s.isEnrolled).length;

  int get votesCast => slots.where((s) => s.hasVoted).length;

  FcgVoterSlot? slotForAddress(String address) {
    for (final slot in slots) {
      if (slot.matchesAddress(address)) return slot;
    }
    return null;
  }

  FcgVoterSlot? slotByNumber(int slotNumber) {
    for (final slot in slots) {
      if (slot.slot == slotNumber) return slot;
    }
    return null;
  }

  FcgQuorumSnapshot get quorumSnapshot =>
      const FcgQuorumEngine().evaluate(
        this,
        quorumPercent: quorumThresholdPercent,
      );

  Map<FcgVoteChoice, int> get tally {
    final counts = {
      FcgVoteChoice.support: 0,
      FcgVoteChoice.oppose: 0,
      FcgVoteChoice.abstain: 0,
    };
    for (final slot in slots) {
      final choice = slot.vote;
      if (choice != null) counts[choice] = counts[choice]! + 1;
    }
    return counts;
  }

  FcgVotingSession copyWith({
    String? id,
    String? regionId,
    String? policyQuestion,
    String? moderatorUsername,
    DateTime? createdAt,
    FcgSessionStatus? status,
    bool? runCohesion,
    bool? runPercent,
    double? cohesionScs,
    bool clearCohesionScs = false,
    double? percentChance,
    bool clearPercentChance = false,
    String? cohesionNarrative,
    String? percentNarrative,
    String? linkedScenarioRunId,
    bool clearLinkedScenarioRunId = false,
    List<FcgVoterSlot>? slots,
    FcgAuditLog? auditLog,
    double? quorumThresholdPercent,
  }) =>
      FcgVotingSession(
        id: id ?? this.id,
        regionId: regionId ?? this.regionId,
        policyQuestion: policyQuestion ?? this.policyQuestion,
        moderatorUsername: moderatorUsername ?? this.moderatorUsername,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        runCohesion: runCohesion ?? this.runCohesion,
        runPercent: runPercent ?? this.runPercent,
        cohesionScs:
            clearCohesionScs ? null : (cohesionScs ?? this.cohesionScs),
        percentChance:
            clearPercentChance ? null : (percentChance ?? this.percentChance),
        cohesionNarrative: cohesionNarrative ?? this.cohesionNarrative,
        percentNarrative: percentNarrative ?? this.percentNarrative,
        linkedScenarioRunId: clearLinkedScenarioRunId
            ? null
            : (linkedScenarioRunId ?? this.linkedScenarioRunId),
        slots: slots ?? this.slots,
        auditLog: auditLog ?? this.auditLog,
        quorumThresholdPercent:
            quorumThresholdPercent ?? this.quorumThresholdPercent,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'regionId': regionId,
        'policyQuestion': policyQuestion,
        'moderatorUsername': moderatorUsername,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status.name,
        'runCohesion': runCohesion,
        'runPercent': runPercent,
        if (cohesionScs != null) 'cohesionScs': cohesionScs,
        if (percentChance != null) 'percentChance': percentChance,
        'cohesionNarrative': cohesionNarrative,
        'percentNarrative': percentNarrative,
        if (linkedScenarioRunId != null)
          'linkedScenarioRunId': linkedScenarioRunId,
        'slots': slots.map((s) => s.toJson()).toList(),
        'auditLog': auditLog.toJsonList(),
        'quorumThresholdPercent': quorumThresholdPercent,
      };

  factory FcgVotingSession.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] ?? json['voters'];
    return FcgVotingSession(
      id: json['id'] as String,
      regionId: json['regionId'] as String? ?? 'global',
      policyQuestion: json['policyQuestion'] as String? ?? '',
      moderatorUsername: json['moderatorUsername'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      status: FcgSessionStatus.values
              .asNameMap()[json['status'] as String? ?? ''] ??
          FcgSessionStatus.draft,
      runCohesion: json['runCohesion'] as bool? ?? true,
      runPercent: json['runPercent'] as bool? ?? true,
      cohesionScs: (json['cohesionScs'] as num?)?.toDouble(),
      percentChance: (json['percentChance'] as num?)?.toDouble(),
      cohesionNarrative: json['cohesionNarrative'] as String? ?? '',
      percentNarrative: json['percentNarrative'] as String? ?? '',
      linkedScenarioRunId: json['linkedScenarioRunId'] as String?,
      slots: _parseSlots(rawSlots),
      auditLog: FcgAuditLog.fromJsonList(json['auditLog'] as List<dynamic>?),
      quorumThresholdPercent:
          (json['quorumThresholdPercent'] as num?)?.toDouble() ??
              FcgQuorumEngine.defaultQuorumPercent,
    );
  }

  static List<FcgVoterSlot> _parseSlots(dynamic raw) {
    final list = raw as List<dynamic>? ?? [];
    if (list.isEmpty) return FcgWardDatabase.seedSlots();
    final parsed = list
        .map((e) => FcgVoterSlot.fromJson(e as Map<String, dynamic>))
        .toList();
    return FcgWardDatabase.normalizeSlots(parsed);
  }
}

/// Local FCG parish database — scenario history + ward sessions + voter slots.
class FcgWardDatabase {
  const FcgWardDatabase({
    this.scenarioRuns = const [],
    this.sessions = const [],
    this.activeSessionId,
  });

  static const int slotCount = 30;

  final List<FcgScenarioRun> scenarioRuns;
  final List<FcgVotingSession> sessions;
  final String? activeSessionId;

  FcgVotingSession? get activeSession {
    if (activeSessionId == null) return null;
    for (final session in sessions) {
      if (session.id == activeSessionId) return session;
    }
    return null;
  }

  FcgWardDatabase copyWith({
    List<FcgScenarioRun>? scenarioRuns,
    List<FcgVotingSession>? sessions,
    String? activeSessionId,
    bool clearActiveSessionId = false,
  }) =>
      FcgWardDatabase(
        scenarioRuns: scenarioRuns ?? this.scenarioRuns,
        sessions: sessions ?? this.sessions,
        activeSessionId: clearActiveSessionId
            ? null
            : (activeSessionId ?? this.activeSessionId),
      );

  Map<String, dynamic> toJson() => {
        'scenarioRuns': scenarioRuns.map((r) => r.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        if (activeSessionId != null) 'activeSessionId': activeSessionId,
      };

  factory FcgWardDatabase.fromJson(Map<String, dynamic> json) =>
      FcgWardDatabase(
        scenarioRuns: (json['scenarioRuns'] as List<dynamic>? ?? [])
            .map((e) => FcgScenarioRun.fromJson(e as Map<String, dynamic>))
            .toList(),
        sessions: (json['sessions'] as List<dynamic>? ?? [])
            .map((e) => FcgVotingSession.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeSessionId: json['activeSessionId'] as String?,
      );

  static List<FcgVoterSlot> seedSlots() => List.generate(
        slotCount,
        (i) => FcgVoterSlot(slot: i + 1),
      );

  static List<FcgVoterSlot> normalizeSlots(List<FcgVoterSlot> slots) {
    final bySlot = {for (final s in slots) s.slot: s};
    return List.generate(
      slotCount,
      (i) => bySlot[i + 1] ?? FcgVoterSlot(slot: i + 1),
    );
  }
}