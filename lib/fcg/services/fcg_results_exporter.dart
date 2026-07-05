import 'dart:convert';

import '../models/fcg_audit_log.dart';
import '../models/fcg_models.dart';
import 'fcg_quorum_engine.dart';

/// Pilot-ready parish vote results — JSON + Markdown export.
class FcgResultsExporter {
  const FcgResultsExporter({FcgQuorumEngine? quorum})
      : _quorum = quorum ?? const FcgQuorumEngine();

  final FcgQuorumEngine _quorum;

  Map<String, dynamic> buildJson({
    required FcgVotingSession session,
    required FcgAuditLog auditLog,
    required String regionLabel,
    double quorumPercent = FcgQuorumEngine.defaultQuorumPercent,
  }) {
    final snapshot = _quorum.evaluate(session, quorumPercent: quorumPercent);
    return {
      'exportVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'session': {
        'id': session.id,
        'regionId': session.regionId,
        'regionLabel': regionLabel,
        'policyQuestion': session.policyQuestion,
        'status': session.status.name,
        'moderatorUsername': session.moderatorUsername,
        'createdAt': session.createdAt.toUtc().toIso8601String(),
        'cohesionScs': session.cohesionScs,
        'percentChance': session.percentChance,
      },
      'quorum': snapshot.toJson(),
      'slots': session.slots
          .map(
            (s) => {
              'slot': s.slot,
              'enrolled': s.isEnrolled,
              'vote': s.vote?.name,
              'committedAt': s.committedAt?.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
      'auditLog': auditLog.toJsonList(),
      'auditTipHash': auditLog.tipHash,
    };
  }

  String buildJsonString({
    required FcgVotingSession session,
    required FcgAuditLog auditLog,
    required String regionLabel,
    double quorumPercent = FcgQuorumEngine.defaultQuorumPercent,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      buildJson(
        session: session,
        auditLog: auditLog,
        regionLabel: regionLabel,
        quorumPercent: quorumPercent,
      ),
    );
  }

  String buildMarkdown({
    required FcgVotingSession session,
    required FcgAuditLog auditLog,
    required String regionLabel,
    double quorumPercent = FcgQuorumEngine.defaultQuorumPercent,
  }) {
    final q = _quorum.evaluate(session, quorumPercent: quorumPercent);
    final buf = StringBuffer()
      ..writeln('# FCG Parish Vote — Pilot Results')
      ..writeln()
      ..writeln('**Region:** $regionLabel')
      ..writeln('**Policy:** ${session.policyQuestion}')
      ..writeln('**Status:** ${session.status.name}')
      ..writeln('**Exported:** ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln()
      ..writeln('## Live tally')
      ..writeln('- Support: ${q.support}')
      ..writeln('- Oppose: ${q.oppose}')
      ..writeln('- Abstain: ${q.abstain} (counts for quorum, not decision)')
      ..writeln('- Enrolled: ${q.enrolled} / ${FcgWardDatabase.slotCount}')
      ..writeln('- Ballots cast: ${q.votesCast}')
      ..writeln()
      ..writeln('## Quorum engine')
      ..writeln(
        '- Participation: ${q.participationRate.toStringAsFixed(1)}% '
        '(threshold ${q.quorumThresholdPercent.toStringAsFixed(0)}%)',
      )
      ..writeln('- Quorum met: ${q.quorumMet ? 'yes' : 'no'}')
      ..writeln('- Deciding votes (excl. abstain): ${q.decidingVotes}')
      ..writeln(
        '- Support share of deciding: '
        '${q.supportSharePercent.toStringAsFixed(1)}%',
      )
      ..writeln('- **Outcome:** ${q.outcome.name}')
      ..writeln()
      ..writeln('## Chronoflux analysis')
      ..writeln(
        session.cohesionScs != null
            ? '- SCS: ~${session.cohesionScs!.round()}/100'
            : '- SCS: —',
      )
      ..writeln(
        session.percentChance != null
            ? '- Percent chance: ${session.percentChance!.toStringAsFixed(1)}%'
            : '- Percent chance: —',
      )
      ..writeln()
      ..writeln('## Slot roster')
      ..writeln('| Slot | Enrolled | Vote |')
      ..writeln('| --- | --- | --- |');
    for (final slot in session.slots) {
      buf.writeln(
        '| ${slot.slotLabel} | ${slot.isEnrolled ? 'yes' : '—'} | '
        '${slot.vote?.name ?? '—'} |',
      );
    }
    buf
      ..writeln()
      ..writeln('## Immutable audit log (${auditLog.entries.length} entries)')
      ..writeln('| Time | Action | Actor | Slot | Detail |')
      ..writeln('| --- | --- | --- | --- | --- |');
    for (final entry in auditLog.entries) {
      buf.writeln(
        '| ${entry.timestamp.toUtc().toIso8601String()} '
        '| ${entry.action.name} '
        '| ${entry.actor} '
        '| ${entry.slotNumber ?? '—'} '
        '| ${entry.detail ?? entry.voteName ?? '—'} |',
      );
    }
    buf
      ..writeln()
      ..writeln('Audit chain tip: `${auditLog.tipHash}`');
    return buf.toString();
  }
}