import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/analysis_mode.dart';
import '../../models/scenario_input.dart';
import '../../providers/locale_provider.dart';
import '../../services/evolve_engine.dart';
import '../models/ward_proposal.dart';
import '../providers/perc_wallet_provider.dart';
import '../widgets/chronoflux_five_point_graph_panel.dart';
import '../widgets/wallet_creator_credit.dart';

/// v2.0 main dapp — community ward voting with open scenario probability checker.
class CommunityWardVotingScreen extends StatelessWidget {
  const CommunityWardVotingScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.t('wallet_dapp_ward_voting')),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.how_to_vote_outlined, size: 20),
                text: strings.t('ward_voting_tab_vote'),
              ),
              Tab(
                icon: const Icon(Icons.analytics_outlined, size: 20),
                text: strings.t('ward_voting_tab_scenario'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _WardVoteTab(strings: strings),
            _WardScenarioCheckerTab(strings: strings),
          ],
        ),
      ),
    );
  }
}

class _WardVoteTab extends StatefulWidget {
  const _WardVoteTab({required this.strings});

  final AppLocalizations strings;

  @override
  State<_WardVoteTab> createState() => _WardVoteTabState();
}

class _WardVoteTabState extends State<_WardVoteTab> {
  String? _selectedProposalId;
  final _commentController = TextEditingController();
  WardVoteChoice? _pendingChoice;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
            const SizedBox(height: 16),
            ChronofluxFivePointGraphPanel(
              wallet: wallet,
              strings: widget.strings,
              compact: true,
            ),
            const SizedBox(height: 16),
            if (!wallet.isLoggedIn)
              Card(
                color: const Color(0xFF1A1F2E),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.strings.t('ward_voting_login_required'),
                    style: const TextStyle(color: Color(0xFFFFB347)),
                  ),
                ),
              )
            else if (proposals.isEmpty)
              Text(
                widget.strings.t('ward_voting_no_proposals'),
                style: const TextStyle(color: Color(0xFF9BA3B8)),
              )
            else ...[
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
              if (_selectedProposalId != null) ...[
                const SizedBox(height: 12),
                _proposalDetail(
                  proposals.firstWhere((p) => p.id == _selectedProposalId),
                ),
                const SizedBox(height: 12),
                _tallyCard(wallet, _selectedProposalId!),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: widget.strings.t('ward_voting_comment_label'),
                    hintText: widget.strings.t('ward_voting_comment_hint'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
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
                if (wallet.wardBallotFor(_selectedProposalId!) != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.strings.t('ward_voting_already_cast'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF00D9C0)),
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

  Widget _proposalDetail(WardProposal proposal) {
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

  Widget _tallyCard(PercWalletProvider wallet, String proposalId) {
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
  const _WardScenarioCheckerTab({required this.strings});

  final AppLocalizations strings;

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