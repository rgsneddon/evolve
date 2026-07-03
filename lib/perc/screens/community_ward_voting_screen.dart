import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/analysis_mode.dart';
import '../../models/scenario_input.dart';
import '../../providers/locale_provider.dart';
import '../../services/evolve_engine.dart';
import '../models/ward_conclusion_link.dart';
import '../models/ward_proposal.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/ward_conclusion_bridge.dart';
import '../widgets/chronoflux_five_point_graph_panel.dart';
import '../widgets/ward_dual_metric_populator.dart';
import '../widgets/wallet_creator_credit.dart';

/// v2.0 main dapp — community ward voting with open scenario probability checker.
class CommunityWardVotingScreen extends StatefulWidget {
  const CommunityWardVotingScreen({
    super.key,
    required this.strings,
    this.initialLink,
  });

  final AppLocalizations strings;
  final WardConclusionLink? initialLink;

  @override
  State<CommunityWardVotingScreen> createState() =>
      _CommunityWardVotingScreenState();
}

class _CommunityWardVotingScreenState extends State<CommunityWardVotingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  WardConclusionLink? _pendingPopulateLink;
  int _populateGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _populateVoteFields(WardConclusionLink link) {
    setState(() {
      _pendingPopulateLink = link;
      _populateGeneration++;
    });
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strings.t('wallet_dapp_ward_voting')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.how_to_vote_outlined, size: 20),
              text: widget.strings.t('ward_voting_tab_vote'),
            ),
            Tab(
              icon: const Icon(Icons.analytics_outlined, size: 20),
              text: widget.strings.t('ward_voting_tab_scenario'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WardVoteTab(
            strings: widget.strings,
            initialLink: widget.initialLink,
            populateLink: _pendingPopulateLink,
            populateGeneration: _populateGeneration,
          ),
          _WardScenarioCheckerTab(
            strings: widget.strings,
            onPopulateVoteFields: _populateVoteFields,
          ),
        ],
      ),
    );
  }
}

class _WardVoteTab extends StatefulWidget {
  const _WardVoteTab({
    required this.strings,
    this.initialLink,
    this.populateLink,
    this.populateGeneration = 0,
  });

  final AppLocalizations strings;
  final WardConclusionLink? initialLink;
  final WardConclusionLink? populateLink;
  final int populateGeneration;

  @override
  State<_WardVoteTab> createState() => _WardVoteTabState();
}

class _WardVoteTabState extends State<_WardVoteTab> {
  String? _selectedProposalId;
  final _commentController = TextEditingController();
  final _proposalTitleController = TextEditingController();
  final _proposalSummaryController = TextEditingController();
  final _proposalWardController = TextEditingController();
  WardVoteChoice? _pendingChoice;
  bool _submittingProposal = false;
  bool _appliedConclusionLink = false;
  int _lastPopulateGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyConclusionLink();
      _applyPopulateLink();
    });
  }

  @override
  void didUpdateWidget(covariant _WardVoteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.populateGeneration != oldWidget.populateGeneration) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyPopulateLink());
    }
  }

  void _applyLinkToFields(WardConclusionLink link) {
    final wallet = context.read<PercWalletProvider>();
    final match = wallet.openWardProposals
        .where((p) => WardConclusionLink.normalizeTitle(p.title) == link.matchKey)
        .toList();

    setState(() {
      if (match.isNotEmpty) {
        _selectedProposalId = match.first.id;
        _commentController.text = link.voteCommentPrefill;
      } else {
        _proposalTitleController.text = link.title;
        _proposalSummaryController.text = link.summary;
        _proposalWardController.text = link.wardName;
        _commentController.text = link.voteCommentPrefill;
      }
    });
  }

  void _applyConclusionLink() {
    if (_appliedConclusionLink || !mounted) return;
    final raw = widget.initialLink ??
        context.read<PercWalletProvider>().pendingWardConclusionLink;
    if (raw == null) return;

    _appliedConclusionLink = true;
    final locale = context.read<LocaleProvider>().config;
    final enriched = WardConclusionBridge.enrichLinkToDual(
      seed: raw,
      locale: locale,
      strings: widget.strings,
    );
    context.read<PercWalletProvider>().setPendingWardConclusionLink(enriched);
    _applyLinkToFields(enriched);
  }

  void _applyPopulateLink() {
    if (!mounted) return;
    final link = widget.populateLink;
    if (link == null || widget.populateGeneration == _lastPopulateGeneration) {
      return;
    }
    _lastPopulateGeneration = widget.populateGeneration;
    _applyLinkToFields(link);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _proposalTitleController.dispose();
    _proposalSummaryController.dispose();
    _proposalWardController.dispose();
    super.dispose();
  }

  Future<void> _submitProposal(PercWalletProvider wallet) async {
    setState(() => _submittingProposal = true);
    final proposal = await wallet.submitWardProposal(
      title: _proposalTitleController.text,
      summary: _proposalSummaryController.text,
      wardName: _proposalWardController.text,
    );
    if (!mounted) return;
    setState(() => _submittingProposal = false);
    if (proposal != null) {
      setState(() => _selectedProposalId = proposal.id);
      _proposalTitleController.clear();
      _proposalSummaryController.clear();
      _proposalWardController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.t('ward_proposal_listed_ok'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final proposals = wallet.openWardProposals;
    _selectedProposalId ??=
        proposals.isNotEmpty ? proposals.first.id : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.strings.t('ward_voting_intro'),
              style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8), height: 1.45),
            ),
            if (widget.initialLink != null || wallet.pendingWardConclusionLink != null) ...[
              const SizedBox(height: 12),
              _conclusionLinkBanner(
                widget.initialLink ?? wallet.pendingWardConclusionLink!,
              ),
            ],
            const SizedBox(height: 16),
            WardDualMetricPopulator(
              strings: widget.strings,
              seedLink: widget.initialLink ??
                  wallet.pendingWardConclusionLink,
              onPopulate: _applyLinkToFields,
            ),
            const SizedBox(height: 16),
            ChronofluxFivePointGraphPanel(
              wallet: wallet,
              strings: widget.strings,
              compact: true,
            ),
            const SizedBox(height: 16),
            if (wallet.isLoggedIn) ...[
              _submitProposalCard(wallet),
              const SizedBox(height: 16),
            ] else
              Card(
                color: const Color(0xFF1A1F2E),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.strings.t('ward_voting_login_required'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9BA3B8),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (proposals.isEmpty)
              Text(
                widget.strings.t('ward_voting_no_proposals'),
                style: const TextStyle(color: Color(0xFF9BA3B8)),
              ),
            if (proposals.isNotEmpty) ...[
              Text(
                widget.strings.t('ward_voting_public_results_title'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.strings.t('ward_voting_public_results_note'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 12),
              ...proposals.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _publicProposalResultsCard(wallet, p),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.strings.t('ward_voting_select_proposal'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedProposalId,
                decoration: InputDecoration(
                  labelText: widget.strings.t('ward_voting_select_proposal'),
                ),
                items: proposals
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(() => _selectedProposalId = id),
              ),
              if (_selectedProposalId != null && wallet.isLoggedIn) ...[
                const SizedBox(height: 12),
                _proposalDetail(
                  proposals.firstWhere((p) => p.id == _selectedProposalId),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.strings.t('ward_voting_comment_label'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: widget.strings.t('ward_voting_comment_hint'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (wallet.hasVotedOnWardProposal(_selectedProposalId!)) ...[
                  Text(
                    widget.strings.t('ward_voting_vote_locked'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00D9C0),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.strings.t('ward_voting_already_cast'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _pendingChoice != null
                              ? null
                              : () => _cast(wallet, WardVoteChoice.forProposal),
                          child: Text(widget.strings.t('ward_voting_for')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pendingChoice != null
                              ? null
                              : () => _cast(wallet, WardVoteChoice.against),
                          child: Text(widget.strings.t('ward_voting_against')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: _pendingChoice != null
                              ? null
                              : () => _cast(wallet, WardVoteChoice.abstain),
                          child: Text(widget.strings.t('ward_voting_abstain')),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
            const SizedBox(height: 24),
            WalletCreatorCredit(strings: widget.strings),
          ],
        ),
      ),
    );
  }

  Widget _conclusionLinkBanner(WardConclusionLink link) {
    final metricsLine = link.dualAnalysis &&
            link.percentChance != null &&
            link.refinedScs != null
        ? '${widget.strings.t('ward_scenario_percent_title')} · ${link.percentChance!.round()}%'
            ' · ${widget.strings.t('ward_scenario_scs_title')} · ${link.refinedScs!.round()}/100'
        : link.analysisMode == AnalysisMode.percentChance
            ? '${widget.strings.t('mode_percent')} · ${link.outcomeScore.round()}%'
            : '${widget.strings.t('mode_cohesion')} · ${link.outcomeScore.round()}/100 SCS';

    return Card(
      color: const Color(0xFF6C63FF).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, size: 18, color: Color(0xFF6C63FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.strings.t('ward_conclusion_link_loaded'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB8B5FF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              metricsLine,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            if (link.grokEnriched) ...[
              const SizedBox(height: 4),
              Text(
                widget.strings.t('ward_conclusion_link_grok_badge'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00D9C0),
                ),
              ),
            ],
            if (link.conclusionExcerpt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                link.conclusionExcerpt,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFB8BFD0)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _submitProposalCard(PercWalletProvider wallet) {
    return Card(
      color: const Color(0xFF22C55E).withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.strings.t('ward_proposal_submit_title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _proposalTitleController,
              decoration: InputDecoration(
                labelText: widget.strings.t('ward_proposal_title_label'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _proposalSummaryController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.strings.t('ward_proposal_summary_label'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _proposalWardController,
              decoration: InputDecoration(
                labelText: widget.strings.t('ward_proposal_ward_label'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submittingProposal ? null : () => _submitProposal(wallet),
              icon: _submittingProposal
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined, size: 18),
              label: Text(widget.strings.t('ward_proposal_submit_button')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proposalDetail(WardProposal proposal) {
    final daysLeft = proposal.listingDaysRemaining(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              proposal.wardName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.strings
                  .t('ward_proposal_by')
                  .replaceAll('{user}', proposal.proposerUsername),
              style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 4),
            Text(
              widget.strings
                  .t('ward_proposal_days_left')
                  .replaceAll('{days}', '$daysLeft'),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              proposal.summary,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _publicProposalResultsCard(
    PercWalletProvider wallet,
    WardProposal proposal,
  ) {
    final total = wallet.wardTotalVotesFor(proposal.id);
    final ballots = wallet.wardPublicBallotsFor(proposal.id);
    final isSelected = _selectedProposalId == proposal.id;

    return Material(
      color: isSelected
          ? const Color(0xFF22C55E).withOpacity(0.08)
          : const Color(0xFF1A1F2E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedProposalId = proposal.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proposal.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.strings
                    .t('ward_proposal_days_left')
                    .replaceAll('{days}', '${proposal.listingDaysRemaining(DateTime.now())}'),
                style: const TextStyle(fontSize: 10, color: Color(0xFF22C55E)),
              ),
              const SizedBox(height: 10),
              _tallyRow(wallet, proposal.id),
              const SizedBox(height: 8),
              Text(
                widget.strings
                    .t('ward_voting_total_ballots')
                    .replaceAll('{count}', '$total'),
                style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 10),
              Text(
                widget.strings.t('ward_voting_public_comments'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (ballots.isEmpty)
                Text(
                  widget.strings.t('ward_voting_no_ballots_yet'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                )
              else
                ...ballots.take(5).map(_publicCommentTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _publicCommentTile(WardBallot ballot) {
    final choiceLabel = switch (ballot.choice) {
      WardVoteChoice.forProposal => widget.strings.t('ward_voting_comment_choice_for'),
      WardVoteChoice.against => widget.strings.t('ward_voting_comment_choice_against'),
      WardVoteChoice.abstain => widget.strings.t('ward_voting_comment_choice_abstain'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ballot.voterUsername} · $choiceLabel',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF)),
          ),
          if (ballot.comment.isNotEmpty)
            Text(
              ballot.comment,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8), height: 1.4),
            ),
        ],
      ),
    );
  }

  Widget _tallyRow(PercWalletProvider wallet, String proposalId) {
    final tally = wallet.wardTallyFor(proposalId);
    return Row(
      children: [
        _tallyChip(widget.strings.t('ward_voting_for'), tally[WardVoteChoice.forProposal] ?? 0, const Color(0xFF00D9C0)),
        const SizedBox(width: 8),
        _tallyChip(widget.strings.t('ward_voting_against'), tally[WardVoteChoice.against] ?? 0, const Color(0xFFE74C3C)),
        const SizedBox(width: 8),
        _tallyChip(widget.strings.t('ward_voting_abstain'), tally[WardVoteChoice.abstain] ?? 0, const Color(0xFF9BA3B8)),
      ],
    );
  }

  Widget _tallyChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9BA3B8))),
          ],
        ),
      ),
    );
  }

  Future<void> _cast(PercWalletProvider wallet, WardVoteChoice choice) async {
    final id = _selectedProposalId;
    if (id == null) return;
    setState(() => _pendingChoice = choice);
    final ok = await wallet.castWardVote(
      proposalId: id,
      choice: choice,
      comment: _commentController.text,
    );
    if (!mounted) return;
    setState(() => _pendingChoice = null);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.t('ward_voting_cast_ok'))),
      );
    }
  }
}

class _WardScenarioCheckerTab extends StatefulWidget {
  const _WardScenarioCheckerTab({
    required this.strings,
    required this.onPopulateVoteFields,
  });

  final AppLocalizations strings;
  final ValueChanged<WardConclusionLink> onPopulateVoteFields;

  @override
  State<_WardScenarioCheckerTab> createState() => _WardScenarioCheckerTabState();
}

class _WardScenarioCheckerTabState extends State<_WardScenarioCheckerTab> {
  final _topicController = TextEditingController();
  final _questionController = TextEditingController();
  bool _running = false;
  double? _percentChance;
  double? _refinedScs;
  String? _percentPhrase;
  String? _scsLean;
  String? _error;

  @override
  void dispose() {
    _topicController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _error = widget.strings.t('ward_scenario_need_question'));
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _percentChance = null;
      _refinedScs = null;
    });

    final locale = context.read<LocaleProvider>().config;
    final input = ScenarioInput(
      topic: _topicController.text.trim(),
      posedQuestion: question,
    );
    const engine = EvolveEngine();

    try {
      final pctResult = engine.analyze(
        input,
        mode: AnalysisMode.percentChance,
        locale: locale,
      );
      final scsResult = engine.analyze(
        input,
        mode: AnalysisMode.cohesionScore,
        locale: locale,
      );
      if (!mounted) return;
      setState(() {
        _percentChance = pctResult.percentChance;
        _percentPhrase = pctResult.percentPhrase;
        _refinedScs = scsResult.core.refinedScs;
        _scsLean = scsResult.core.lean;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _running = false;
      });
    }
  }

  void _populateVoteFields() {
    final question = _questionController.text.trim();
    if (question.isEmpty || _percentChance == null || _refinedScs == null) {
      return;
    }
    final locale = context.read<LocaleProvider>().config;
    final input = ScenarioInput(
      topic: _topicController.text.trim(),
      posedQuestion: question,
    );
    final link = WardConclusionBridge.buildFromScenario(
      input: input,
      locale: locale,
      strings: widget.strings,
    );
    widget.onPopulateVoteFields(link);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.t('ward_dual_populated_ok'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.strings.t('ward_scenario_intro'),
              style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8), height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: widget.strings.t('ward_scenario_topic_label'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: widget.strings.t('ward_scenario_question_label'),
                hintText: widget.strings.t('ward_scenario_question_hint'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _runCheck,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(widget.strings.t('ward_scenario_run')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFE74C3C))),
            ],
            if (_percentChance != null && _refinedScs != null) ...[
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _resultCard(
                    title: widget.strings.t('ward_scenario_percent_title'),
                    value: '${_percentChance!.round()}%',
                    subtitle: _percentPhrase ?? '',
                    color: const Color(0xFF6C63FF),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _resultCard(
                    title: widget.strings.t('ward_scenario_scs_title'),
                    value: '${_refinedScs!.round()}/100',
                    subtitle: _scsLean ?? '',
                    color: const Color(0xFF00D9C0),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _populateVoteFields,
                icon: const Icon(Icons.input_outlined, size: 18),
                label: Text(widget.strings.t('ward_dual_populate_button')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.strings.t('ward_scenario_free_note'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 24),
            WalletCreatorCredit(strings: widget.strings),
          ],
        ),
      ),
    );
  }

  Widget _resultCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8), height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}