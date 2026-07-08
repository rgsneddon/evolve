import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/synopsis_delivery.dart';

import '../../l10n/app_localizations.dart';
import '../../models/locale_config.dart';
import '../../perc/providers/perc_wallet_provider.dart';
import '../../providers/locale_provider.dart';
import '../mishi/fcg_mishi_permission.dart';
import '../models/fcg_models.dart';
import '../providers/fcg_voting_provider.dart';
import '../services/fcg_governance_paper.dart';
import '../services/fcg_moderator.dart';
import '../services/fcg_quorum_engine.dart';
import '../widgets/fcg_mishi_moderator_gate.dart';

/// Full Community Governance parish council voting — SSUCF cohesion narratives.
class FcgVotingScreen extends StatefulWidget {
  const FcgVotingScreen({
    super.key,
    @visibleForTesting this.skipInitialAccessRefresh = false,
  });

  /// When true, [initState] does not await Mishi permission I/O (widget tests).
  @visibleForTesting
  final bool skipInitialAccessRefresh;

  @override
  State<FcgVotingScreen> createState() => _FcgVotingScreenState();
}

class _FcgVotingScreenState extends State<FcgVotingScreen> {
  final _policyController = TextEditingController();
  bool _runCohesion = true;
  bool _runPercent = true;
  bool _accessChecked = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipInitialAccessRefresh) {
      _accessChecked = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVotingAccess());
    }
  }

  Future<void> _refreshVotingAccess() async {
    final wallet = context.read<PercWalletProvider>();
    final fcg = context.read<FcgVotingProvider>();
    final locale = context.read<LocaleProvider>().config;
    await fcg.refreshVotingAccess(
      walletAddress: wallet.address,
      walletUsername: wallet.loggedInUsername,
      regionId: locale.regionId,
      locale: locale,
    );
    if (mounted) setState(() => _accessChecked = true);
  }

  @override
  void dispose() {
    _policyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        AppLocalizations.of(context.watch<LocaleProvider>().config);
    final locale = context.watch<LocaleProvider>().config;
    final fcg = context.watch<FcgVotingProvider>();
    final wallet = context.watch<PercWalletProvider>();

    final regionId = locale.regionId;
    final regionLabel = FcgModerator.regionLabel(regionId);
    final modUsername = fcg.moderatorUsernameForRegion(regionId);
    final isModerator = fcg.isModerator(wallet.loggedInUsername);
    final session = fcg.activeSession;
    final narratives = fcg.cohesionNarrativesForRegion(regionId);
    final userSlot = fcg.slotForWalletAddress(wallet.address);
    final canVote = fcg.canWalletVote(wallet.address);
    final votingUnlocked = isModerator || fcg.votingAccessApproved;

    if (!_accessChecked) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!votingUnlocked) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _votingAccessBlocked(
                strings: strings,
                modUsername: modUsername,
                regionLabel: regionLabel,
                status: fcg.votingAccessStatus,
                onRequest: wallet.isLoggedIn && !fcg.busy
                    ? () async {
                        await fcg.requestVotingAccess(
                          walletAddress: wallet.address,
                          walletUsername: wallet.loggedInUsername ?? '',
                          regionId: regionId,
                        );
                        await _refreshVotingAccess();
                      }
                    : null,
                onRefresh: _refreshVotingAccess,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(strings, regionLabel),
                const SizedBox(height: 16),
                _governanceLink(strings),
                const SizedBox(height: 16),
                if (!fcg.ready)
                  const LinearProgressIndicator(minHeight: 2),
                if (fcg.busy) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
                if (fcg.statusMessage != null) ...[
                  const SizedBox(height: 12),
                  _statusBanner(strings.t(fcg.statusMessage!)),
                ],
                if (fcg.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _errorBanner(strings.t(fcg.errorMessage!)),
                ],
                const SizedBox(height: 16),
                _moderatorCard(
                  strings: strings,
                  modUsername: modUsername,
                  isModerator: isModerator,
                  walletUsername: wallet.loggedInUsername,
                ),
                const SizedBox(height: 16),
                if (session == null)
                  _initiateCard(
                    strings: strings,
                    isModerator: isModerator,
                    runCohesion: _runCohesion,
                    runPercent: _runPercent,
                    onCohesionChanged: (v) => setState(() => _runCohesion = v),
                    onPercentChanged: (v) => setState(() => _runPercent = v),
                    policyController: _policyController,
                    onInitiate: isModerator && !fcg.busy
                        ? () => _initiateVote(
                              fcg: fcg,
                              wallet: wallet,
                              regionId: regionId,
                              locale: locale,
                            )
                        : null,
                  )
                else ...[
                  _resultsDashboard(
                    strings: strings,
                    session: session,
                    regionLabel: regionLabel,
                    fcg: fcg,
                  ),
                  const SizedBox(height: 16),
                  _narrativePicker(
                    strings: strings,
                    narratives: narratives,
                    session: session,
                    isModerator: isModerator,
                    onLink: (id) => fcg.linkNarrativeToSession(id),
                  ),
                  const SizedBox(height: 16),
                  if (canVote)
                    _userVotePanel(
                      strings: strings,
                      session: session,
                      userSlot: userSlot!,
                      narratives: narratives,
                      fcg: fcg,
                      walletAddress: wallet.address,
                    ),
                  if (wallet.isLoggedIn && userSlot == null) ...[
                    const SizedBox(height: 16),
                    _notEnrolledCard(strings),
                  ],
                  if (isModerator) ...[
                    const SizedBox(height: 16),
                    _adminEnrollmentPanel(
                      strings: strings,
                      session: session,
                      fcg: fcg,
                      moderatorUsername: wallet.loggedInUsername!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _slotRoster(strings, session, isModerator),
                  if (isModerator) ...[
                    const SizedBox(height: 16),
                    _auditLogPanel(strings, session),
                  ],
                  if (isModerator) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: fcg.busy
                            ? null
                            : () => fcg.closeActiveSession(),
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: Text(strings.t('fcg_close_session')),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                _scenarioHistory(strings, narratives),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initiateVote({
    required FcgVotingProvider fcg,
    required PercWalletProvider wallet,
    required String regionId,
    required LocaleConfig locale,
  }) async {
    await fcg.initiateSession(
      moderatorUsername: wallet.loggedInUsername!,
      regionId: regionId,
      policyQuestion: _policyController.text,
      runCohesion: _runCohesion,
      runPercent: _runPercent,
      locale: locale,
    );
  }

  Widget _header(AppLocalizations strings, String regionLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.t('fcg_title'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          strings
              .t('fcg_subtitle')
              .replaceAll('{region}', regionLabel),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFFD8DCE8),
          ),
        ),
      ],
    );
  }

  Widget _votingAccessBlocked({
    required AppLocalizations strings,
    required String modUsername,
    required String regionLabel,
    required FcgMishiPermissionStatus? status,
    required Future<void> Function()? onRequest,
    required Future<void> Function() onRefresh,
  }) {
    String statusKey = 'fcg_voting_access_blocked_body';
    if (status == FcgMishiPermissionStatus.pending) {
      statusKey = 'fcg_voting_access_pending';
    } else if (status == FcgMishiPermissionStatus.rejected) {
      statusKey = 'fcg_voting_access_rejected';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              strings.t('fcg_voting_access_blocked_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              strings
                  .t(statusKey)
                  .replaceAll('{mod}', modUsername)
                  .replaceAll('{region}', regionLabel),
              style: const TextStyle(fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (onRequest != null &&
                status != FcgMishiPermissionStatus.pending)
              FilledButton.icon(
                onPressed: onRequest,
                icon: const Icon(Icons.how_to_reg_outlined),
                label: Text(strings.t('fcg_voting_access_request_button')),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(strings.t('fcg_voting_access_refresh')),
            ),
            FcgMishiModeratorGate(strings: strings),
          ],
        ),
      ),
    );
  }

  Widget _governanceLink(AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance_outlined,
                color: Color(0xFF6C63FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                strings.t('fcg_governance_blurb'),
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(FcgGovernancePaper.url),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(strings.t('fcg_read_paper')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moderatorCard({
    required AppLocalizations strings,
    required String modUsername,
    required bool isModerator,
    required String? walletUsername,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isModerator ? Icons.verified_user : Icons.admin_panel_settings_outlined,
                  color: isModerator
                      ? const Color(0xFF34D399)
                      : const Color(0xFF9BA3B8),
                ),
                const SizedBox(width: 8),
                Text(
                  strings.t('fcg_moderator_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              strings.t('fcg_moderator_account_hint'),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            if (walletUsername != null) ...[
              const SizedBox(height: 8),
              Text(
                strings
                    .t('fcg_signed_in_as')
                    .replaceAll('{user}', walletUsername),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9BA3B8),
                ),
              ),
            ],
            if (!isModerator) ...[
              const SizedBox(height: 8),
              Text(
                strings.t('fcg_moderator_sign_in_hint'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _initiateCard({
    required AppLocalizations strings,
    required bool isModerator,
    required bool runCohesion,
    required bool runPercent,
    required ValueChanged<bool> onCohesionChanged,
    required ValueChanged<bool> onPercentChanged,
    required TextEditingController policyController,
    required VoidCallback? onInitiate,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.t('fcg_initiate_title'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: policyController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: strings.t('fcg_policy_question'),
                hintText: strings.t('fcg_policy_question_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.t('fcg_analysis_modes'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.t('fcg_run_cohesion')),
              value: runCohesion,
              onChanged: (v) => onCohesionChanged(v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.t('fcg_run_percent')),
              value: runPercent,
              onChanged: (v) => onPercentChanged(v ?? false),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onInitiate,
              icon: const Icon(Icons.how_to_vote_outlined),
              label: Text(strings.t('fcg_initiate_button')),
            ),
            if (!isModerator) ...[
              const SizedBox(height: 8),
              Text(
                strings.t('fcg_initiate_moderator_only'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultsDashboard({
    required AppLocalizations strings,
    required FcgVotingSession session,
    required String regionLabel,
    required FcgVotingProvider fcg,
  }) {
    final q = session.quorumSnapshot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('fcg_results_dashboard'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              session.policyQuestion,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 12),
            _outcomeBanner(strings, q.outcome),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: q.enrolled > 0 ? q.participationRate / 100 : 0,
              minHeight: 6,
              backgroundColor: const Color(0xFF2D3348),
            ),
            const SizedBox(height: 8),
            Text(
              strings
                  .t('fcg_quorum_participation')
                  .replaceAll('{pct}', q.participationRate.toStringAsFixed(1))
                  .replaceAll(
                    '{threshold}',
                    q.quorumThresholdPercent.toStringAsFixed(0),
                  )
                  .replaceAll(
                    '{met}',
                    q.quorumMet
                        ? strings.t('fcg_quorum_met_yes')
                        : strings.t('fcg_quorum_met_no'),
                  ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tallyChip(strings.t('fcg_vote_support'), q.support,
                    const Color(0xFF34D399)),
                _tallyChip(strings.t('fcg_vote_oppose'), q.oppose,
                    const Color(0xFFF87171)),
                _tallyChip(strings.t('fcg_vote_abstain'), q.abstain,
                    const Color(0xFF9BA3B8)),
                _chip(
                  strings
                      .t('fcg_deciding_votes')
                      .replaceAll('{count}', '${q.decidingVotes}'),
                ),
                _chip(
                  strings
                      .t('fcg_enrolled_count')
                      .replaceAll('{enrolled}', '${q.enrolled}')
                      .replaceAll('{total}', '${FcgWardDatabase.slotCount}'),
                ),
                _chip(regionLabel),
              ],
            ),
            if (q.decidingVotes > 0) ...[
              const SizedBox(height: 8),
              Text(
                strings
                    .t('fcg_support_share')
                    .replaceAll('{pct}', q.supportSharePercent.toStringAsFixed(1)),
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyExport(
                    context,
                    fcg.exportResultsMarkdown(
                      session: session,
                      regionLabel: regionLabel,
                    ),
                    strings.t('fcg_export_copied_md'),
                  ),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: Text(strings.t('fcg_export_copy_md')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyExport(
                    context,
                    fcg.exportResultsJson(
                      session: session,
                      regionLabel: regionLabel,
                    ),
                    strings.t('fcg_export_copied_json'),
                  ),
                  icon: const Icon(Icons.data_object_outlined, size: 16),
                  label: Text(strings.t('fcg_export_copy_json')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveExport(
                    context,
                    fcg.exportResultsMarkdown(
                      session: session,
                      regionLabel: regionLabel,
                    ),
                    'fcg-pilot-${session.id}',
                    strings,
                  ),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(strings.t('fcg_export_save_md')),
                ),
              ],
            ),
            if (session.cohesionNarrative.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                strings.t('fcg_session_narrative'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                _excerpt(session.cohesionNarrative, 480),
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _outcomeBanner(AppLocalizations strings, FcgVoteOutcome outcome) {
    final (label, color) = switch (outcome) {
      FcgVoteOutcome.pass => (strings.t('fcg_outcome_pass'), const Color(0xFF34D399)),
      FcgVoteOutcome.fail => (strings.t('fcg_outcome_fail'), const Color(0xFFF87171)),
      FcgVoteOutcome.tie => (strings.t('fcg_outcome_tie'), const Color(0xFFF59E0B)),
      FcgVoteOutcome.noQuorum => (
          strings.t('fcg_outcome_no_quorum'),
          const Color(0xFF9BA3B8),
        ),
      FcgVoteOutcome.pending => (
          strings.t('fcg_outcome_pending'),
          const Color(0xFF6C63FF),
        ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.how_to_vote, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  void _copyExport(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveExport(
    BuildContext context,
    String markdown,
    String basename,
    AppLocalizations strings,
  ) async {
    final saved = await SynopsisDelivery.exportTextFile(
      text: markdown,
      basename: basename,
    );
    if (!context.mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('fcg_export_saved'))),
      );
    }
  }

  Widget _auditLogPanel(AppLocalizations strings, FcgVotingSession session) {
    final entries = session.auditLog.entries;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings
                  .t('fcg_audit_log_title')
                  .replaceAll('{count}', '${entries.length}'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('fcg_audit_log_hint'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 8),
            Text(
              strings
                  .t('fcg_audit_chain_tip')
                  .replaceAll('{hash}', _excerpt(session.auditLog.tipHash, 16)),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(strings.t('fcg_audit_empty')),
              )
            else
              ...entries.reversed.take(12).map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${e.action.name} · slot ${e.slotNumber ?? '—'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        '${e.timestamp.toUtc().toIso8601String()} · ${e.actor}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _narrativePicker({
    required AppLocalizations strings,
    required List<FcgScenarioRun> narratives,
    required FcgVotingSession session,
    required bool isModerator,
    required ValueChanged<String> onLink,
  }) {
    if (narratives.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            strings.t('fcg_no_narratives'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('fcg_narrative_picker_title'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('fcg_narrative_picker_hint'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 12),
            ...narratives.take(8).map((run) {
              final selected = session.linkedScenarioRunId == run.id;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  run.posedQuestion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  _excerpt(run.narrativeExcerpt, 120),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: isModerator
                    ? TextButton(
                        onPressed: selected ? null : () => onLink(run.id),
                        child: Text(
                          selected
                              ? strings.t('fcg_narrative_linked')
                              : strings.t('fcg_link_narrative'),
                        ),
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _userVotePanel({
    required AppLocalizations strings,
    required FcgVotingSession session,
    required FcgVoterSlot userSlot,
    required List<FcgScenarioRun> narratives,
    required FcgVotingProvider fcg,
    required String walletAddress,
  }) {
    return _UserBallotPanel(
      strings: strings,
      userSlot: userSlot,
      narratives: narratives,
      fcg: fcg,
      walletAddress: walletAddress,
      voteLabel: _voteLabel,
    );
  }

  Widget _notEnrolledCard(AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, color: Color(0xFF9BA3B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                strings.t('fcg_not_enrolled_hint'),
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminEnrollmentPanel({
    required AppLocalizations strings,
    required FcgVotingSession session,
    required FcgVotingProvider fcg,
    required String moderatorUsername,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('fcg_admin_panel_title'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('fcg_admin_panel_hint'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 12),
            ...session.slots.map(
              (slot) => _adminSlotRow(
                strings: strings,
                session: session,
                slot: slot,
                fcg: fcg,
                moderatorUsername: moderatorUsername,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminSlotRow({
    required AppLocalizations strings,
    required FcgVotingSession session,
    required FcgVoterSlot slot,
    required FcgVotingProvider fcg,
    required String moderatorUsername,
  }) {
    return _AdminSlotRow(
      key: ValueKey('fcg-admin-slot-${slot.slot}'),
      strings: strings,
      session: session,
      slot: slot,
      fcg: fcg,
      moderatorUsername: moderatorUsername,
    );
  }

  Widget _slotRoster(
    AppLocalizations strings,
    FcgVotingSession session,
    bool isModerator,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('fcg_slot_roster_title'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: session.slots.map((slot) {
                final status = !slot.isEnrolled
                    ? strings.t('fcg_slot_empty')
                    : slot.hasVoted
                        ? _voteLabel(strings, slot.vote!)
                        : strings.t('fcg_slot_enrolled');
                return Chip(
                  label: Text(
                    '${strings.t('fcg_slot_label')} ${slot.slotLabel}: $status',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            if (!isModerator) ...[
              const SizedBox(height: 8),
              Text(
                strings.t('fcg_slot_roster_public_hint'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scenarioHistory(
    AppLocalizations strings,
    List<FcgScenarioRun> narratives,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('fcg_history_title'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('fcg_history_hint'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            if (narratives.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                strings.t('fcg_history_empty'),
                style: const TextStyle(fontSize: 12),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ...narratives.take(6).map(
                    (run) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(run.posedQuestion, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        _excerpt(run.narrativeExcerpt, 100),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(String message) => _banner(message, const Color(0xFF1F3A2F));
  Widget _errorBanner(String message) => _banner(message, const Color(0xFF3A1F1F));

  Widget _banner(String message, Color bg) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _tallyChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text('$count', style: const TextStyle(fontSize: 10)),
      ),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
    );
  }

  String _voteLabel(AppLocalizations strings, FcgVoteChoice choice) =>
      switch (choice) {
        FcgVoteChoice.support => strings.t('fcg_vote_support'),
        FcgVoteChoice.oppose => strings.t('fcg_vote_oppose'),
        FcgVoteChoice.abstain => strings.t('fcg_vote_abstain'),
      };

  String _excerpt(String text, int max) {
    final trimmed = text.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}

class _UserBallotPanel extends StatefulWidget {
  const _UserBallotPanel({
    required this.strings,
    required this.userSlot,
    required this.narratives,
    required this.fcg,
    required this.walletAddress,
    required this.voteLabel,
  });

  final AppLocalizations strings;
  final FcgVoterSlot userSlot;
  final List<FcgScenarioRun> narratives;
  final FcgVotingProvider fcg;
  final String walletAddress;
  final String Function(AppLocalizations, FcgVoteChoice) voteLabel;

  @override
  State<_UserBallotPanel> createState() => _UserBallotPanelState();
}

class _UserBallotPanelState extends State<_UserBallotPanel> {
  String? _selectedNarrativeId;

  @override
  void initState() {
    super.initState();
    _selectedNarrativeId = widget.userSlot.linkedScenarioRunId;
  }

  @override
  void didUpdateWidget(covariant _UserBallotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedNarrativeId = widget.userSlot.linkedScenarioRunId;
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final slot = widget.userSlot;
    final fcg = widget.fcg;

    return Card(
      color: const Color(0xFF1A2332),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings
                  .t('fcg_your_ballot_title')
                  .replaceAll('{slot}', slot.slotLabel),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('fcg_your_ballot_hint'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            if (widget.narratives.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _selectedNarrativeId,
                decoration: InputDecoration(
                  labelText: strings.t('fcg_voter_narrative'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(strings.t('fcg_no_narrative')),
                  ),
                  ...widget.narratives.take(12).map(
                        (run) => DropdownMenuItem<String?>(
                          value: run.id,
                          child: Text(
                            run.posedQuestion.length > 48
                                ? '${run.posedQuestion.substring(0, 48)}…'
                                : run.posedQuestion,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                ],
                onChanged: slot.hasVoted
                    ? null
                    : (id) => setState(() => _selectedNarrativeId = id),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: FcgVoteChoice.values.map((choice) {
                final selected = slot.vote == choice;
                return ChoiceChip(
                  label: Text(widget.voteLabel(strings, choice)),
                  selected: selected,
                  onSelected: fcg.busy
                      ? null
                      : (v) {
                          if (v) {
                            fcg.castUserVote(
                              walletAddress: widget.walletAddress,
                              vote: choice,
                              linkedScenarioRunId: _selectedNarrativeId,
                            );
                          }
                        },
                );
              }).toList(),
            ),
            if (slot.hasVoted) ...[
              const SizedBox(height: 8),
              Text(
                strings
                    .t('fcg_ballot_recorded')
                    .replaceAll(
                      '{choice}',
                      widget.voteLabel(strings, slot.vote!),
                    ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF34D399)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminSlotRow extends StatefulWidget {
  const _AdminSlotRow({
    super.key,
    required this.strings,
    required this.session,
    required this.slot,
    required this.fcg,
    required this.moderatorUsername,
  });

  final AppLocalizations strings;
  final FcgVotingSession session;
  final FcgVoterSlot slot;
  final FcgVotingProvider fcg;
  final String moderatorUsername;

  @override
  State<_AdminSlotRow> createState() => _AdminSlotRowState();
}

class _AdminSlotRowState extends State<_AdminSlotRow> {
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _addressController =
        TextEditingController(text: widget.slot.percAddress ?? '');
  }

  @override
  void didUpdateWidget(covariant _AdminSlotRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final committed = widget.slot.percAddress ?? '';
    if (committed != _addressController.text) {
      _addressController.text = committed;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final slot = widget.slot;
    final fcg = widget.fcg;
    final reEnroll =
        widget.session.auditLog.slotHasEnrollmentHistory(slot.slot);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '${strings.t('fcg_slot_label')} ${slot.slotLabel}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _addressController,
              enabled: !slot.isEnrolled,
              decoration: InputDecoration(
                labelText: strings.t('fcg_perc_address'),
                hintText: strings.t('fcg_perc_address_hint'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              FilledButton(
                onPressed: fcg.busy || slot.isEnrolled
                    ? null
                    : () {
                        final enroll = reEnroll
                            ? fcg.reEnrollSlotAddress
                            : fcg.commitSlotAddress;
                        enroll(
                          slotNumber: slot.slot,
                          percAddress: _addressController.text,
                          moderatorUsername: widget.moderatorUsername,
                        );
                      },
                child: Text(
                  reEnroll
                      ? strings.t('fcg_reenroll_address')
                      : strings.t('fcg_commit_address'),
                ),
              ),
              if (slot.isEnrolled) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: fcg.busy
                      ? null
                      : () => fcg.releaseSlot(
                            slotNumber: slot.slot,
                            moderatorUsername: widget.moderatorUsername,
                          ),
                  child: Text(strings.t('fcg_release_slot')),
                ),
                TextButton(
                  onPressed: fcg.busy
                      ? null
                      : () => fcg.clearSlotAddress(
                            slotNumber: slot.slot,
                            moderatorUsername: widget.moderatorUsername,
                          ),
                  child: Text(strings.t('fcg_clear_address')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}