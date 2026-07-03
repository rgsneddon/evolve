import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analysis_mode.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../perc/screens/community_ward_voting_screen.dart';
import '../perc/services/ward_conclusion_bridge.dart';
import '../providers/evolve_provider.dart';

/// Link from an Evolve conclusion into Community Ward Voting with readable payload.
class ConclusionWardVoteLink extends StatelessWidget {
  const ConclusionWardVoteLink({
    super.key,
    this.conclusionExcerpt,
    this.accentColor = const Color(0xFF22C55E),
  });

  final String? conclusionExcerpt;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final evolve = context.watch<EvolveProvider>();
    final strings = evolve.strings;
    final result = evolve.result;
    if (result == null) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () => _openWardVoting(context, evolve),
      icon: Icon(Icons.how_to_vote_outlined, size: 18, color: accentColor),
      label: Text(strings.t('ward_conclusion_link_button')),
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: BorderSide(color: accentColor.withOpacity(0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  void _openWardVoting(BuildContext context, EvolveProvider evolve) {
    final result = evolve.result;
    if (result == null) return;

    final link = WardConclusionBridge.buildBestEffortDual(
      currentResult: result,
      currentMode: evolve.mode,
      input: evolve.input,
      locale: evolve.locale,
      strings: evolve.strings,
      percentResult: evolve.resultForMode(AnalysisMode.percentChance),
      cohesionResult: evolve.resultForMode(AnalysisMode.cohesionScore),
      conclusionExcerptOverride: conclusionExcerpt,
      grokConstrualEnabled: evolve.grokConstrualEnabled,
    );

    final wallet = context.read<PercWalletProvider>();
    wallet.setPendingWardConclusionLink(link);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityWardVotingScreen(
          strings: evolve.strings,
          initialLink: link,
        ),
      ),
    );
  }
}