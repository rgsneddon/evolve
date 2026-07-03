import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/localized_output.dart';
import '../models/evolve_result.dart';
import '../models/part_percent_breakdown.dart';
import '../providers/evolve_provider.dart';
import '../services/conclusion_explainer.dart';
import '../services/question_semantics.dart';

import 'explainer_card.dart';
import 'part_two_panel.dart';

class PercentChancePanel extends StatelessWidget {
  const PercentChancePanel({super.key, required this.result, this.question});

  final EvolveResult result;
  final String? question;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EvolveProvider>();
    final locale = provider.locale;
    final strings = provider.strings;
    final compact = MediaQuery.sizeOf(context).width < 520;
    final split = ConclusionExplainer.splitGrokReply(result.grokStyleReply, locale);
    final posedSubject = QuestionSemantics.fromText(
      question ?? '',
      regionId: locale.regionId,
      regionLabel: provider.output.regionName(locale.regionId),
    ).displaySubject;
    final regressive = result.core.lean == 'REGRESSIVE';
    final lean = provider.output.leanLabel(result.core.lean);
    final outcomeSubtitle = provider.output.percentOutcomeSubtitle(
      lean: lean,
      regressive: regressive,
    );
    final outcomePhrase = provider.output.percentOutcomePhraseLine(
      percentPhrase: result.percentPhrase,
      regressive: regressive,
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0x336C63FF),
                  child: Icon(Icons.auto_awesome, size: 16, color: Color(0xFFB8B5FF)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.t('grok_title'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(strings.t('grok_subtitle'),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.grokStyleReply));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.t('grok_copied'))),
                    );
                  },
                ),
              ],
            ),
            if (question != null && question!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00D9C0).withOpacity(0.3)),
                ),
                child: Text(question!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00D9C0))),
              ),
            ],
            PartTwoPanel(partTwo: result.partTwo),
            const SizedBox(height: 16),
            Text(
              '${result.percentChance.round()}%',
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00D9C0),
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              outcomeSubtitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: regressive ? const Color(0xFFFF8A7A) : const Color(0xFF7AE582),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              outcomePhrase,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (result.partBreakdown != null &&
                result.partBreakdown!.isNotEmpty) ...[
              const SizedBox(height: 20),
              PartBreakdownSection(
                breakdown: result.partBreakdown!,
                output: provider.output,
                compact: compact,
              ),
            ],
            const SizedBox(height: 14),
            ConclusionBlock(
              text: split.conclusion.isNotEmpty
                  ? split.conclusion
                  : '${provider.output.grokConclusionMarker} ${result.continuumConclusion}',
            ),
            const SizedBox(height: 14),
            ExplainerCard(
              title: strings.t('explainer_how_read'),
              body: ConclusionExplainer.percentChance(
                result,
                locale: locale,
                posedSubject: posedSubject.isNotEmpty ? posedSubject : null,
              ),
              bullets: ConclusionExplainer.percentChanceBullets(result, locale),
              accentColor: const Color(0xFF00D9C0),
            ),
          ],
        ),
      ),
    );
  }
}

class PartBreakdownSection extends StatelessWidget {
  const PartBreakdownSection({
    super.key,
    required this.breakdown,
    required this.output,
    required this.compact,
  });

  final PartPercentBreakdown breakdown;
  final LocalizedOutput output;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          output.partBreakdownTitle(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (breakdown.outcomeContext.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            output.partBreakdownOutcome(breakdown.outcomeContext),
            style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          output.partBreakdownNote(),
          style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
        ),
        const SizedBox(height: 12),
        ...breakdown.parts.map(
          (part) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PartBreakdownRow(part: part, output: output, compact: compact),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          output.partBreakdownTotal(breakdown.partitionTotal),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF00D9C0),
          ),
        ),
      ],
    );
  }
}

class _PartBreakdownRow extends StatelessWidget {
  const _PartBreakdownRow({
    required this.part,
    required this.output,
    required this.compact,
  });

  final PartPercentResult part;
  final LocalizedOutput output;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final regressive = part.isRegressive;
    final lean = output.leanLabel(part.lean);
    final leanLine = output.partBreakdownLeanLine(
      lean: lean,
      regressive: regressive,
      regressivePct: part.regressivePct.round(),
      progressivePct: part.progressivePct.round(),
    );
    final accent = regressive ? const Color(0xFFFF8A7A) : const Color(0xFF7AE582);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  part.percentPhrase,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB8B5C8)),
                ),
                const SizedBox(height: 2),
                Text(
                  leanLine,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${part.percentChance.round()}%',
            style: TextStyle(
              fontSize: compact ? 28 : 32,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}