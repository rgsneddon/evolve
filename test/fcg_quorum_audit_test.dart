import 'package:evolve/fcg/models/fcg_audit_log.dart';
import 'package:evolve/fcg/models/fcg_models.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_quorum_engine.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/fcg/services/fcg_results_exporter.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quorum treats abstentions as participation not decision votes', () {
    final session = FcgVotingSession(
      id: 's1',
      regionId: 'uk_ireland',
      policyQuestion: 'Levy?',
      moderatorUsername: 'MOD_UK',
      createdAt: DateTime.utc(2026, 7, 4),
      slots: [
        FcgVoterSlot(slot: 1, percAddress: 'percpriv1${'a' * 40}', vote: FcgVoteChoice.support),
        FcgVoterSlot(slot: 2, percAddress: 'percpriv1${'b' * 40}', vote: FcgVoteChoice.abstain),
        ...List.generate(28, (i) => FcgVoterSlot(slot: i + 3)),
      ],
    );

    final q = const FcgQuorumEngine().evaluate(session);
    expect(q.support, 1);
    expect(q.abstain, 1);
    expect(q.decidingVotes, 1);
    expect(q.votesCast, 2);
    expect(q.participationRate, 100);
    expect(q.quorumMet, isTrue);
    expect(q.outcome, FcgVoteOutcome.pass);
  });

  test('audit log is append-only with hash chain', () {
    var log = const FcgAuditLog();
    log = log.append(
      FcgAuditEntry(
        id: 'a1',
        timestamp: DateTime.utc(2026, 7, 4),
        action: FcgAuditAction.sessionOpened,
        actor: 'MOD_UK',
        prevHash: log.tipHash,
      ),
    );
    log = log.append(
      FcgAuditEntry(
        id: 'a2',
        timestamp: DateTime.utc(2026, 7, 4, 1),
        action: FcgAuditAction.addressCommitted,
        actor: 'MOD_UK',
        slotNumber: 1,
        prevHash: log.tipHash,
      ),
    );

    expect(log.entries.length, 2);
    expect(log.entries.first.prevHash, 'genesis');
    expect(log.entries.last.prevHash, log.entries.first.entryHash);
    expect(log.tipHash, log.entries.last.entryHash);
    expect(log.tipHash, isNot('genesis'));
  });

  test('release and re-enroll flow is audited', () async {
    final addr1 = 'percpriv1${'a' * 40}';
    final addr2 = 'percpriv1${'c' * 40}';
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await fcg.initialize();
    await fcg.initiateSession(
      moderatorUsername: 'MOD_UK',
      regionId: 'uk_ireland',
      policyQuestion: 'Pilot levy',
      runCohesion: true,
      runPercent: false,
      locale: const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'),
    );

    await fcg.commitSlotAddress(
      slotNumber: 1,
      percAddress: addr1,
      moderatorUsername: 'MOD_UK',
    );
    await fcg.releaseSlot(
      slotNumber: 1,
      moderatorUsername: 'MOD_UK',
    );
    await fcg.reEnrollSlotAddress(
      slotNumber: 1,
      percAddress: addr2,
      moderatorUsername: 'MOD_UK',
    );

    final session = fcg.activeSession!;
    final actions = session.auditLog.entries.map((e) => e.action).toList();
    expect(actions, contains(FcgAuditAction.slotReleased));
    expect(actions, contains(FcgAuditAction.addressReEnrolled));
    expect(session.slotByNumber(1)?.percAddress, addr2);

    final md = fcg.exportResultsMarkdown(
      session: session,
      regionLabel: 'UK & Ireland',
    );
    expect(md, contains('Immutable audit log'));
    expect(md, contains('addressReEnrolled'));
  });

  test('exporter emits JSON with audit tip hash', () {
    final session = FcgVotingSession(
      id: 's-export',
      regionId: 'uk_ireland',
      policyQuestion: 'Q',
      moderatorUsername: 'MOD',
      createdAt: DateTime.utc(2026, 7, 4),
      auditLog: const FcgAuditLog().append(
        FcgAuditEntry(
          id: 'e1',
          timestamp: DateTime.utc(2026, 7, 4),
          action: FcgAuditAction.sessionOpened,
          actor: 'MOD',
          prevHash: 'genesis',
        ),
      ),
    );
    final json = const FcgResultsExporter().buildJsonString(
      session: session,
      auditLog: session.auditLog,
      regionLabel: 'UK',
    );
    expect(json, contains('auditTipHash'));
    expect(json, contains('quorum'));
  });
}