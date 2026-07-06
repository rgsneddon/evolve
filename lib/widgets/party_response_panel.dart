import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/party_response_scs.dart';
import '../l10n/app_localizations.dart';
import '../providers/evolve_provider.dart';
import '../providers/locale_provider.dart';

/// Per-party SCS breakdown when a linked narrative relies on attributed responses.
class PartyResponsePanel extends StatelessWidget {
  const PartyResponsePanel({super.key, required this.refinement});

  final NarrativePartyRefinement refinement;

  @override
  Widget build(BuildContext context) {
    if (!refinement.applied) return const SizedBox.shrink();

    final provider = context.watch<EvolveProvider>();
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);
    final out = provider.output;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_outlined,
                  size: 18, color: Color(0xFFA78BFA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  out.partyResponsePanelTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFFC4B5FD),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            refinement.summary,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9BA3B8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          ...refinement.responses.map((response) => _ResponseCard(
                response: response,
                strings: strings,
                leanLabel: out.leanLabel(response.lean),
              )),
          const SizedBox(height: 4),
          Text(
            strings
                .t('party_response_refined')
                .replaceAll(
                    '{before}', '${refinement.narrativeScsBefore.round()}')
                .replaceAll(
                    '{after}', '${refinement.refinedNarrativeScs.round()}'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFC4B5FD),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.response,
    required this.strings,
    required this.leanLabel,
  });

  final PartyResponseScore response;
  final dynamic strings;
  final String leanLabel;

  @override
  Widget build(BuildContext context) {
    final scsLine = strings
        .t('party_response_scs')
        .replaceAll('{scs}', '${response.scs.round()}')
        .replaceAll('{reg}', '${response.regressivePct.round()}')
        .replaceAll('{prog}', '${response.progressivePct.round()}')
        .replaceAll('{lean}', leanLabel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response.party,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: Color(0xFFE9D5FF),
            ),
          ),
          if (response.role.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              response.role,
              style: const TextStyle(fontSize: 11, color: Color(0xFF7C8499)),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            scsLine,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9BA3B8)),
          ),
          const SizedBox(height: 4),
          Text(
            '"${response.excerpt}"',
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Color(0xFFB8BFD0),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}