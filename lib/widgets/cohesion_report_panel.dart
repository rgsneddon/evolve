import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/evolve_result.dart';
import '../providers/evolve_provider.dart';
import '../services/conclusion_explainer.dart';
import 'explainer_card.dart';
import 'party_response_panel.dart';
import 'part_two_panel.dart';

class CohesionReportPanel extends StatelessWidget {
  const CohesionReportPanel({super.key, required this.result});

  final EvolveResult result;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EvolveProvider>();
    final locale = provider.locale;
    final strings = provider.strings;
    final report = result.cohesionReport;
    final score = result.core.refinedScs;
    final split = ConclusionExplainer.splitCohesionReport(report, locale);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Color(0xFF6C63FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(strings.t('mode_cohesion'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: report));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.t('report_copied'))),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '~${score.round()}/100',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    strings.t('cohesion_refined_panel').replaceAll('{scs}', '${score.round()}'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8), height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PartTwoPanel(partTwo: result.partTwo),
            if (result.partyRefinement != null &&
                result.partyRefinement!.applied)
              PartyResponsePanel(refinement: result.partyRefinement!),
            const Divider(),
            const SizedBox(height: 12),
            SelectableText(
              split.body.isNotEmpty ? split.body : report,
              style: const TextStyle(fontSize: 12.5, height: 1.55, color: Color(0xFFB8BFD0)),
            ),
            if (split.conclusion.isNotEmpty) ...[
              const SizedBox(height: 16),
              ConclusionBlock(
                text: split.conclusion,
                accentColor: const Color(0xFF6C63FF),
              ),
            ],
            const SizedBox(height: 14),
            ExplainerCard(
              title: strings.t('explainer_how_read'),
              body: ConclusionExplainer.cohesion(result, locale),
              bullets: ConclusionExplainer.cohesionBullets(result, locale),
            ),
          ],
        ),
      ),
    );
  }
}